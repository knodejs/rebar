-module({{appid}}).
-export([start/0]).


start() ->
    ok = application:start(xmerl),
    ok = application:start(sockjs),
    ok = application:start(ranch),
    ok = application:start(crypto),   
    ok = application:start(cowlib), 
    ok = application:start(cowboy),
    ok = application:start(asn1),
    ok = application:start(public_key),
    ok = application:start(ssl),
    ok = application:start(idna),
    ok = application:start(gproc),
    ok = application:start(uuid),
    ok = application:start(cowboy_session),
    hackney:start(),
    ok = application:start({{appid}}).