public class CommandSequence
{

    public string[] commands;

    public CommandSequence( string[] commands )
    {
        this.commands = commands;
    }

    public CommandSequence.from_string( string commands )
    {
        set_commands_from_string( commands );
    }

    public void set_commands_from_string( string commands )
    {
        var lines = commands.split_set( "\n" );
        var cmd_idx = -1;
        this.commands = new string[ lines.length ];
        for( var line_idx = 0; line_idx < lines.length; ++line_idx )
        {
            var line = lines[ line_idx ].strip();
            if( line.length > 0 )
            {
                this.commands[ ++cmd_idx ] = line;
            }
        }
        this.commands = this.commands[ 0 : 1 + cmd_idx ];
    }

    public string to_string()
    {
        return string.joinv( "\n", commands );
    }

    public Run prepare_run( CommandContext context, string mode )
    {
        string[] commands = new string[ this.commands.length ];
        var regex = new Regex( "(?P<mode>[A-Za-z0-9]+):" );
        var cmd_idx = -1;
        for( int candidate_idx = 0; candidate_idx < this.commands.length; ++candidate_idx )
        {
            MatchInfo info;
            var cmd = this.commands[ candidate_idx ];
            if( regex.match( cmd, 0, out info ) )
            {
                if( info.fetch_named( "mode" ) == mode )
                {
                    cmd = cmd.substring( mode.length + 1 );
                }
                else
                {
                    continue;
                }
            }
            commands[ ++cmd_idx ] = context[ cmd ].strip();
        }
        return new Run( context, commands[ 0 : 1 + cmd_idx ] );
    }

    public class Run
    {
        public string            dir      { public get; private set; }
        public string[]          commands { public get; private set; }
        public int               position { public get; private set; }
        public Gee.Set< string > specials { public get; private set; }

        internal Run( CommandContext context, string[] commands )
        {
            this.dir      = context.dir;
            this.commands = commands;
            this.position = -1;
            this.specials = new Gee.HashSet< string >();
            context.special_commands.@foreach( ( cmd ) => { return this.specials.add( cmd ); } );
        }

        public void start()
            requires( position == -1 )
        {
            run_next();
        }

        private void finish_step( int exit )
        {
            if( exit != 0 )
            {
                /* The previous command finished with an error
                 * We'll abort the sequence.
                 */
                done( this, exit );
            }
            else
            {
                /* The previous command finished with errors.
                 */
                run_next();
            }
        }

        private void run_next()
        {
            ++position;
            step( this );
            if( position == commands.length )
            {
                done( this, 0 );
            }
            else
            if( commands[ position ] in specials )
            {
                try
                {
                    special_command( this, commands[ position ] );
                    finish_step( 0 );
                }
                catch( Error err )
                {
                    finish_step( err.code );
                }
            }
            else
            {
                var cmd = new SimpleCommand( dir, commands[ position ] );
                cmd.done.connect( finish_step );
                cmd.error_changed.connect   ( ( text ) => { stderr_changed( this, text ); } );
                cmd.standard_changed.connect( ( text ) => { stdout_changed( this, text ); } );
                cmd.run();
            }
        }

        public signal void done( Run run, int exit );
        public signal void step( Run run );

        public signal void stdout_changed( Run run, string text );
        public signal void stderr_changed( Run run, string text );

        public signal void special_command( Run run, string command );
    }

}
