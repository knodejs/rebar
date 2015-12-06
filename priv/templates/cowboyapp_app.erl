-module({{appid}}_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).
-export([init/3, handle/2, terminate/3,port/0]).
-define(C_ACCEPTORS,  100).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
	Port = port(),
    setSessionCookie(),
    StateEcho = sockjs_handler:init_state(
                  <<"/echo">>, fun service_echo/3, state,
                  [{response_limit, 4096}]),
    StateClose = sockjs_handler:init_state(
                   <<"/close">>, fun service_close/3, state, []),
    StateAmplify = sockjs_handler:init_state(
                     <<"/amplify">>, fun service_amplify/3, state, []),
    StateBroadcast = sockjs_handler:init_state(
                       <<"/broadcast">>, fun service_broadcast/3, state, []),
    StateDWSEcho = sockjs_handler:init_state(
                  <<"/disabled_websocket_echo">>, fun service_echo/3, state,
                     [{websocket, false}]),
    StateCNEcho = sockjs_handler:init_state(
                    <<"/cookie_needed_echo">>, fun service_echo/3, state,
                    [{cookie_needed, true}]),

    VRoutes = [
               {<<"/echo/[...]">>, sockjs_cowboy_handler, StateEcho},
               {<<"/close/[...]">>, sockjs_cowboy_handler, StateClose},
               {<<"/amplify/[...]">>, sockjs_cowboy_handler, StateAmplify},
               {<<"/broadcast/[...]">>, sockjs_cowboy_handler, StateBroadcast},
               {<<"/disabled_websocket_echo/[...]">>, sockjs_cowboy_handler,StateDWSEcho},
               {<<"/cookie_needed_echo/[...]">>, sockjs_cowboy_handler,StateCNEcho},
               {'_', ?MODULE, []}],
    Routes = [{'_',  VRoutes}],
    Dispatch = cowboy_router:compile(Routes),

    io:format("http://localhost:~p~n", [Port]),

    cowboy:start_http(cowboy_test_server_http_listener, ?C_ACCEPTORS, 
                      [
                        {port, Port}
                      ],
                      [
                        {env, [{dispatch, Dispatch}]},
                        {onrequest, fun cowboy_session:on_request/1}
                      ]),
    receive
        _ -> ok
    end,
    {{appid}}_sup:start_link().

stop(_State) ->
    ok.

init({_Any, http}, Req, []) ->
    {ok, Req, []}.

handle(Req, State) ->
    Host = bitstring_to_list(element(1,cowboy_req:host(Req))),
    Path = bitstring_to_list(element(1,cowboy_req:path(Req))),
    case Path of
        "/" ->
            case Host of
               "localhost" -> %%DEV
                  {ok, Data} = file:read_file("./priv/www/index.html"),
                  {ok, Req1} = cowboy_req:reply(200, [{<<"Content-Type">>, "text/html"}],Data, Req),
                  {ok, Req1, State};
                _ ->  %%Production
                  {ok, Data} = file:read_file("./priv/www/index.min.html"),
                  {ok, Req1} = cowboy_req:reply(200, [{<<"Content-Type">>, "text/html"}],Data, Req),
                  {ok, Req1, State}
            end;
            
        _ ->
            Path_Final = "./priv/www" ++ Path ,
            {ok, Data} = readrequestfile(Path_Final),
            case lists:last(string:tokens(Path, ".")) of
               "js" ->
                    {ok, Req1} = cowboy_req:reply(200, [{<<"Content-Type">>, "text/javascript"}],Data, Req),
                    {ok, Req1, State};
                "css" ->
                    {ok, Req1} = cowboy_req:reply(200, [{<<"Content-Type">>, "text/css"}],Data, Req),
                    {ok, Req1, State};
                "map" ->
                    {ok, Req1} = cowboy_req:reply(200, [{<<"Content-Type">>, "text/css"}],Data, Req),
                    {ok, Req1, State};
                "ico" ->
                    {ok, Req1} = cowboy_req:reply(200, [{<<"Content-Type">>, "image/x-icon"}],Data, Req),
                    {ok, Req1, State};
                _ ->
                    {ok, Req1} = cowboy_req:reply(200, [{<<"Content-Type">>, "text/html"}],Data, Req),
                    {ok, Req1, State}
            end
    end.
    


readrequestfile(Path_Final) ->
    case file:read_file(Path_Final) of 
        {ok, Data} ->
            {ok, Data};
        {error,_} ->
            io:format("Path_Final Error ~p ~n",[Path_Final]),
            {ok, ""}
    end.  

terminate(_Reason, _Req, _State) ->
    ok.

service_close(Conn, _, _State) ->
    Conn:close(3000, "Go away!").


service_amplify(Conn, {recv, Data}, _State) ->
    N0 = list_to_integer(binary_to_list(Data)),
    N = if N0 > 0 andalso N0 < 19 -> N0;
           true                   -> 1
        end,
    Conn:send(list_to_binary(
                  string:copies("x", round(math:pow(2, N)))));
service_amplify(_Conn, _, _State) ->
    ok.

service_echo(_Conn, init, state)        -> 
    {ok, state};
service_echo(Conn, {recv, Data}, state) -> 
     {ok, state};
service_echo(_Conn, {info, _Info}, state) -> 
    {ok, state};
service_echo(_Conn, closed, state)      -> 
    {ok, state}.


service_broadcast(Conn, init, _State) ->
    case ets:info(broadcast_table, memory) of
        undefined ->
            ets:new(broadcast_table, [public, named_table]);
        _Any ->
            ok
    end,
    true = ets:insert(broadcast_table, {Conn}),
    ok;
service_broadcast(Conn, closed, _State) ->
    true = ets:delete_object(broadcast_table, {Conn}),
    ok;
service_broadcast(_Conn, {recv, Data}, _State) ->
    ets:foldl(fun({Conn1}, _Acc) -> Conn1:send(Data) end,
              [], broadcast_table),
    ok.

port() ->
    case os:getenv("PORT") of
        false ->
            {ok, Port} = application:get_env({{appid}},http_port),
            Port;
        Other ->
            list_to_integer(Other)
    end.


setSessionCookie() ->
  ok = cowboy_session_config:set([
    {cookie_name, <<"{{appid}}">>},
    {expire, 86400}
  ]).