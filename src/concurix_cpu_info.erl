-module(concurix_cpu_info).

-export([get_cpu_info/0, get_load_avg/0, get_cpu_times/0]).

get_cpu_info() ->
    case os:type() of
        {unix, linux} ->
            RawInfo = re:split(os:cmd("cat /proc/cpuinfo"), "\n"),
            {ok, group_cpus(parse_cpu_fields(RawInfo))};
        _ ->
            {error, not_linux}
    end.

get_load_avg() ->
    case os:type() of
        {unix, linux} ->
            RawLoad = os:cmd("cat /proc/loadavg"),
            {ok, [Load1, Load5, Load15], _} = io_lib:fread("~f ~f ~f", RawLoad),
            {ok, [Load1, Load5, Load15]};
        _ ->
            {error, not_linux}
    end.

get_cpu_times() ->
    case os:type() of
        {unix, linux} ->
            RawTimes = string:tokens(os:cmd("cat /proc/stat"), "\n"),
            {ok, parse_times(RawTimes)};
        _ ->
            {error, not_linux}
    end.

% ---------- internal ----------

parse_cpu_fields(RawInfo) ->
    parse_cpu_fields(RawInfo, []).

parse_cpu_fields([], Fields) ->
    Fields;
parse_cpu_fields([<<>> | Lines], Fields) ->
    parse_cpu_fields(Lines, Fields);
parse_cpu_fields([Line | Lines], Fields) ->
    Field =
        case re:split(Line, "\t*: ?") of
            [Key] -> parse_cpu_field(Key, <<"">>);
            [Key, Value] -> parse_cpu_field(Key, Value)
        end,
    parse_cpu_fields(Lines, Field ++ Fields).

parse_cpu_field(<<"processor">>, Value) ->
    [{id, list_to_integer(binary_to_list(Value))}];
parse_cpu_field( <<"model name">>, Value) ->
    [{model, Value}];
parse_cpu_field(<<"cpu MHz">>, Value) ->
    [{speed, list_to_float(binary_to_list(Value))}];
parse_cpu_field(_, _) ->
    []. % ignore other fields for now

group_cpus(Fields) ->
    group_cpus(Fields, [], []).

group_cpus([], [], Cpus) -> % {id, _} is always at the end of the list so Cpu should be empty
    Cpus;
group_cpus([Field = {id, _Id} | Fields], Cpu, Cpus) ->
    group_cpus(Fields, [], [[Field | Cpu] | Cpus]);
group_cpus([Field | Fields], Cpu, Cpus) ->
    group_cpus(Fields, [Field | Cpu], Cpus).

parse_times(Lines) ->
    parse_times(Lines, []).

parse_times([], Cpus) ->
    Cpus;
parse_times([Line | Lines], Cpus) ->
    case io_lib:fread("cpu~10u ~d ~d ~d ~d ~d ~d ~d", Line) of
        {ok, [Id, User, Nice, System, Idle, Iowait, Irq, Softirq], _Remaining} ->
            Cpu = {Id, [{user, User}, {nice, Nice}, {sys, System}, {idle, Idle}, {iowait, Iowait}, {irq, Irq}, {softirq, Softirq}]},
            parse_times(Lines, [Cpu | Cpus]);
        _ ->
            parse_times(Lines, Cpus)
    end.
