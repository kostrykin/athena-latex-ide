public class CommandCompletionProvider: Object, Gtk.SourceCompletionProvider
{

    private static string[] built_in_commands =
    {
        "begin",
        "cite",
        "def",
        "end",
        "eqref",
        "label",
        "newline",
        "newcommand",
        "paragraph",
        "ref",
        "renewcommand",
        "section",
        "subsection",
        "subsubsection",
        "usepackage"
    };

    private static Regex acceptance_pattern;
    static construct
    {
        try
        {
            acceptance_pattern = new Regex( "[A-Za-z0-9_:]*$", RegexCompileFlags.ANCHORED | RegexCompileFlags.DOLLAR_ENDONLY );
        }
        catch( RegexError err )
        {
            critical( err.message );
        }
    }

    public weak Editor editor { get; private set; }
    private string? command_input;

    public CommandCompletionProvider( Editor editor )
    {
        this.editor = editor;
    }

    public virtual string get_name()
    {
        return "Commands";
    }

    public virtual bool match( Gtk.SourceCompletionContext context )
    {
        Gtk.TextIter line_start = Gtk.TextIter();
        line_start.assign( context.iter );
        line_start.set_line_offset( 0 );

        Gtk.TextIter c0, c1;
        if( context.iter.backward_search( "\\", 0, out c0, out c1, line_start ) )
        {
            var text = c1.get_text( context.iter );
            if( acceptance_pattern.match_all( text ) )
            {
                command_input = text;
                return true;
            }
        }
        return false;
    }

    private void process_candidate( Gtk.SourceCompletionContext context, Gee.Set< Gtk.SourceCompletionItem > proposals, string command_input, string command )
    {
        if( command.has_prefix( command_input ) )
        {
            proposals.add( new Gtk.SourceCompletionItem( command, command, null, null ) );
        }
    }

    public virtual void populate( Gtk.SourceCompletionContext context )
    {
        var proposals = new Gee.TreeSet< Gtk.SourceCompletionItem >( ( a, b ) => { return a.text.collate( b.text ); } );
        assert( editor.structure != null );
        editor.structure.search_feature( SourceStructure.Feature.COMMAND, ( node ) =>
            {
                if( node is SourceStructure.UsePackageNode )
                {
                    var pkg_node = node as SourceStructure.UsePackageNode;
                    foreach( var command in pkg_node.commands ) process_candidate( context, proposals, command_input, command );
                }
                else
                {
                    var command = node.features[ SourceStructure.Feature.COMMAND ];
                    if( command.length > 0 ) process_candidate( context, proposals, command_input, command );
                }
                return true;
            }
        );
        foreach( var command in built_in_commands ) process_candidate( context, proposals, command_input, command );
        var proposals_list = new List< Gtk.SourceCompletionItem >();
        foreach( var proposal in proposals ) proposals_list.append( proposal );
        context.add_proposals( this, proposals_list, true );
    }

}

