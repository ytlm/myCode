-module(io_widget).
-export([get_state/1,
         start/1, test/0,
         set_handler/2,
         set_prompt/2,
         set_state/2,
         set_title/2, insert_str/2, update_state/3]).

start(Pid) ->
    wx:new(),
    spawn_link(fun() -> widget(Pid) end).

get_state(Pid)           -> rpc(Pid, get_state).
set_title(Pid, Str)      -> Pid ! {title, Str}.
set_handler(Pid, Fun)    -> Pid ! {handler, Fun}.
set_prompt(Pid, Str)     -> Pid ! {prompt, Str}.
set_state(Pid, State)    -> Pid ! {state, State}.
insert_str(Pid, Str)     -> Pid ! {insert, Str}.
update_state(Pid, N, X)  -> Pid ! {updateState, N, X}.

rpc(Pid, Q) ->
    Pid ! {self(), Q},
    receive
        {Pid, R} ->
            R
    end.

widget(Pid) ->
    Size = [{width, 500}, {height, 200}],
    Win  = wx:window(wx:new(),
                     [{map, true}, {configure, true}, {title, "window"}|Size]),
    wx:frame(packer, Win, [{packer_x, [{stretch, 1, 500}]},
                           {packer_y, [{stretch, 10, 120, 100},
                                       {stretch, 1, 15, 15}]}]),
    wx:create(editor, editor, packer, [{pack_x, 1}, {pack_y, 1}, {vscroll, right}]),
    wx:create(entry, entry, packer,   [{pack_x, 1}, {pack_y, 2}, {keypress, true}]),
    wx:config(packer, Size),
    Prompt = " > ",
    State  = nil,
    wx:config(entry, {insert, {0, Prompt}}),
    loop(Win, Pid, Prompt, State, fun parse/1).

loop(Win, Pid, Prompt, State, Parse) ->
    receive
        {From, get_state} ->
            From ! {self(), State},
            loop(Win, Pid, Prompt, State, Parse);
        {handler, Fun} ->
            loop(Win, Pid, Prompt, State, Fun);
        {prompt, Str} ->
            wx:config(entry, {delete, {0, last}}),
            wx:config(entry, {insert, {0, Str}}),
            loop(Win, Pid, Str, State, Parse);
        {state, S} ->
            loop(Win, Pid, Prompt, S, Parse);
        {title, Str} ->
            wx:config(Win, [{title, Str}]),
            loop(Win, Pid, Prompt, State, Parse);
        {insert, Str} ->
            wx:config(editor, {insert, {'end', Str}}),
            scroll_to_show_last_line(),
            loop(Win, Pid, Prompt, State, Parse);
        {updateState, N, X} ->
            io:format("setelemtn N = ~p, X = ~p Stte = ~p~n", [N, X, State]),
            State1 = setelement(N, State, X),
            loop(Win, Pid, Prompt, State1, Parse);
        {wx, _, destroy, _, _} ->
            io:format("Destroyed~n", []),
            exit(windowDestroyed);
        {wx, entry, keypress, _, ['Return'|_]} ->
            Text = wx:read(entry, text),
            wx:config(entry, {delete, {0, last}}),
            wx:config(entry, {insert, {0, Prompt}}),
            try Parse(Text) of
                Term ->
                    Pid ! {self(), State, Term}
            catch
                _:_ ->
                    self() ! {insert, " ** bad input ** \n ** /h for help\n"}
            end,
            loop(Win, Pid, Prompt, State, Parse);
        {wx, _, configure, [], [W, H, _, _]} ->
            wx:config(packer, [{width, W}, {height, H}]),
            loop(Win, Pid, Prompt, State, Parse);
        {wx, entry, keypress, _, _} ->
            loop(Win, Pid, Prompt, State, Parse);
        Any ->
            io:format("Discarded : ~p~n", [Any]),
            loop(Win, Pid, Prompt, State, Parse)
    end.

scroll_to_show_last_line() ->
    Size       = wx:read(editor, size),
    Height     = wx:read(editor, height),
    CharHeight = wx:read(editor, char_height),
    TopRow     = Size - Height / CharHeight,
    if TopRow > 0 -> wx:config(editor, {vscrollpos, TopRow});
       true       -> wx:config(editor, {vscrollpos, 0})
    end.

test() ->
    spawn(fun() -> test1() end).

test1() ->
    W = io_widget:start(self()),
    io_widget:set_title(W, "Test Window"),
    loop(W).

loop(W) ->
    receive
        {W, {str, Str}} ->
            Str1 = Str ++ "\n",
            io_widget:insert_str(W, Str1),
            loop(W)
    end.

parse(Str) ->
    {str, Str}.
