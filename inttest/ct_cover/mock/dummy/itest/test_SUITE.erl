-module(test_SUITE).

-compile(export_all).

-include_lib("ct.hrl").

all() ->
    [simple_test,
     app_config_file_test].

simple_test(Config) ->
    io:format("Test: ~p\n", [Config]).

app_config_file_test(_Config) ->
    application:start(dummy),
    {ok, bar} = application:get_env(dummy, foo),
    application:stop(dummy).
