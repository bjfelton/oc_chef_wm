%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Stephen Delano <stephen@opscode.com>
%% Copyright 2013 Opscode, Inc. All Rights Reserved.

-module(oc_chef_wm_containers_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("chef_objects/include/chef_types.hrl").
-include_lib("oc_chef_authz/include/oc_chef_types.hrl").
-include_lib("eunit/include/eunit.hrl").

-record(context, {reqid :: binary(),
                  otto_connection,
                  darklaunch = undefined}).

-compile(export_all).

-define(ORG_ID, <<"00000000000000000000000000000000">>).
-define(AUTHZ_ID, <<"00000000000000000000000000000001">>).
-define(CLIENT_NAME, <<"test-client">>).

init_per_suite(Config) ->
    Config2 = setup_helper:start_server(Config),

    %% create the test client
    %% {Pubkey, _PrivKey} = chef_wm_util:generate_keypair("name", "reqid"),
    ClientRecord = chef_object:new_record(chef_client,
                                          ?ORG_ID,
                                          ?AUTHZ_ID,
                                          {[{<<"name">>, ?CLIENT_NAME},
                                            {<<"validator">>, true},
                                            {<<"admin">>, true},
                                            {<<"public_key">>, <<"stub-pub">>}]}),
    chef_db:create(ClientRecord,
                   #context{reqid = <<"fake-req-id">>},
                   <<"00000000000000000000000000000001">>),
    Config2.

end_per_suite(Config) ->
    Config2 = setup_helper:stop_server(Config),
    Config2.

all() ->
    [list_when_no_containers, create_container, delete_container, fetch_non_existant_container].

init_per_testcase(_, Config) ->
    delete_all_containers(),
    Config.

delete_all_containers() ->
    Result = case sqerl:adhoc_delete("containers", all) of
        {ok, Count} ->
            Count;
        Error ->
            throw(Error)
    end,
    error_logger:info_msg("Delete containers: ~p", [Result]),
    ok.

list_when_no_containers(_) ->
    Result = ibrowse:send_req("http://localhost:8000/organizations/org/containers",
           [{"x-ops-userid", "test-client"},
            {"accept", "application/json"}],
                     get),
    ?assertMatch({ok, "200", _, _} , Result),
    ok.

create_container(_) ->
    Result = http_create_container("foo"),
    ?assertMatch({ok, "201", _, _} , Result),
    ok.

delete_container(_) ->
    http_create_container("foo"),
    Result = http_delete_container("foo"),
    ?assertMatch({ok, "200", _, _} , Result),
    ok.
    
fetch_non_existant_container(_) ->
    Result = {ok, _, _, ResponseBody} = http_fetch_container("bar"),
    ?assertMatch({ok, "404", _, ResponseBody} , Result),
    ?assertEqual([<<"Cannot load container bar">>], ej:get({"error"}, ejson:decode(ResponseBody))),
    ok.

http_fetch_container(Name) ->
     ibrowse:send_req("http://localhost:8000/organizations/org/containers/" ++ Name,
           [{"x-ops-userid", "test-client"},
            {"accept", "application/json"}],
                     get).

http_create_container(Name) ->
    ibrowse:send_req("http://localhost:8000/organizations/org/containers",
           [{"x-ops-userid", "test-client"},
            {"accept", "application/json"},
            {"content-type", "application/json"}
           ],post,ejson:encode({[{<<"containername">>, list_to_binary(Name)}]})).

http_delete_container(Name) ->
     ibrowse:send_req("http://localhost:8000/organizations/org/containers/" ++ Name,
           [{"x-ops-userid", "test-client"},
            {"accept", "application/json"}
           ], delete).
