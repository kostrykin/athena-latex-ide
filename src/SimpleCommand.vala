/*
 *  Copyright (C) 2011-2013 Lucas Baudin <xapantu@gmail.com>
 *
 *  This program or library is free software; you can redistribute it
 *  and/or modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General
 *  Public License along with this library; if not, write to the
 *  Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301 USA.
 */

/**
 * This class is a wrapper to run an async command. It provides useful signals.
 *
 * This class is forked from Granite 0.3.1. It fixes the following bug:
 * https://bugs.launchpad.net/granite/+bug/1612266
 */
public class SimpleCommand : GLib.Object
{
    static construct
    {
        args_regex = new Regex( """"(?:\\"|[^"])*"|(?:\\ |[^ ])+""" );
    }

    private static Regex args_regex;

    /**
     * Emitted when the command is finished.
     */
    public signal void done(int exit);

    /**
     * When the output changed (std.out and std.err).
     *
     * @param text the new text
     */
    public signal void output_changed(string text);

    /**
     * When the standard output is changed.
     *
     * @param text the new text from std.out
     */
    public signal void standard_changed(string text);

    /**
     * When the error output is changed.
     *
     * @param text the new text from std.err
     */
    public signal void error_changed(string text);

	/**
	 * The whole current standard output
     */
    public string standard_output_str = "";
    /**
     * The whole current error output
     */
    public string error_output_str = "";
    /**
     * The whole current output
     */
    public string output_str = "";
    
    GLib.IOChannel out_make;
    GLib.IOChannel error_out;
    string dir;
    string command;
    Pid pid;

    /**
     * Create a new object. You will have to call run() when you want to run the command.
     *
     * @param dir The working dir
     * @param command The command to execute (using absolute paths like /usr/bin/make causes less
     * strange bugs).
     *
     */
    public SimpleCommand(string dir, string command)
    {
        this.dir = dir;
        this.command = command;
    }

    /**
     * Splits the command into list of arguments.
     */
    private string[] get_args()
    {
        MatchInfo match;
        args_regex.match(command, 0, out match);
        string[] args = new string[ command.split(" ").length ];
        int arg_idx = -1;
        while(match.matches())
        {
            var arg = match.fetch(0);
            arg = arg.replace("\\\"", "\"");
            if(arg.has_prefix("\"") && arg.has_suffix("\""))
            {
                arg = arg.substring(1, arg.length - 2);
            }
            else
            {
                arg = arg.replace("\\ ", " ");
            }
            args[ ++arg_idx ] = arg;
            match.next();
        }
        return args[0 : 1 + arg_idx];
    }

    /**
     * Launch the command. It is async.
     */
    public void run()
    {
        int standard_output = 0;
        int standard_error = 0;
        try
        {
        Process.spawn_async_with_pipes(dir,
                                       get_args(),
                                       null,
                                       SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                       null,
                                       out pid,
                                       null,
                                       out standard_output,
                                       out standard_error);
        }
        catch(Error e)
        {
            critical("Couldn't launch command %s in the directory %s: %s", command, dir, e.message);
        }
        
        ChildWatch.add(pid, (pid, exit) => { done(exit); });

        out_make = new GLib.IOChannel.unix_new(standard_output);
        out_make.add_watch(IOCondition.IN | IOCondition.HUP, (source, condition) => {
            if(condition == IOCondition.HUP)
            {
                return false;
            }
            string output = null;
            
            try
            {
                out_make.read_line(out output, null, null);
            }
            catch(Error e)
            {
                critical("Error in the output retrieving of %s: %s", command, e.message);
            }
        
            
            standard_output_str += output;
            output_str += output;
            standard_changed(output);
            output_changed(output);
            
            return true;
        });

        error_out = new GLib.IOChannel.unix_new(standard_error);
        error_out.add_watch(IOCondition.IN | IOCondition.HUP, (source, condition) => {
            if(condition == IOCondition.HUP)
            {
                return false;
            }
            string output = null;
            try
            {
                error_out.read_line(out output, null, null);
            }
            catch(Error e)
            {
                critical("Error in the output retrieving of %s: %s", command, e.message);
            }
            
            error_output_str += output;
            output_str += output;
            error_changed(output);
            output_changed(output);
            
            return true;
        });
    }
}
