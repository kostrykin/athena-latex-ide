public class CommandContext
{

    public Gee.Map< string, string > variables { public get; private set; default = new Gee.HashMap< string, string >(); }
    public Gee.Set< string >  special_commands { public get; private set; default = new Gee.HashSet< string >(); }

    public string dir;

    public CommandContext( string dir )
    {
        this.dir = dir;
    }

    public string get( owned string command )
    {
        foreach( var key in variables.keys )
        {
            var regex = new Regex( "\\$%s(?![A-Za-z0-9_])".printf( key ) );
            command = regex.replace_literal( command, -1, 0, variables[ key ] );
        }
        return command;
    }

}
