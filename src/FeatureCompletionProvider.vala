public class FeatureCompletionProvider: Object, Gtk.SourceCompletionProvider
{

    private static Regex acceptance_pattern;
    static construct
    {
        try
        {
            acceptance_pattern = new Regex( """((?:\[[^\]]*\])?){[A-Za-z0-9_:]*$""", RegexCompileFlags.ANCHORED | RegexCompileFlags.DOLLAR_ENDONLY );
        }
        catch( RegexError err )
        {
            critical( err.message );
        }
    }

    public weak Editor editor { get; private set; }
    private Gtk.TextIter label_input_start;

    public string match_command;
    public SourceStructure.Feature feature;
    public string name;

    public FeatureCompletionProvider( Editor editor, SourceStructure.Feature feature, string match_command, string name )
    {
        this.name = name;
        this.editor = editor;
        this.feature = feature;
        this.match_command = match_command;
    }

    public virtual string get_name()
    {
        return name;
    }

    public virtual bool match( Gtk.SourceCompletionContext context )
    {
        Gtk.TextIter line_start = Gtk.TextIter();
        line_start.assign( context.iter );
        line_start.set_line_offset( 0 );

        Gtk.TextIter c0, c1;
        if( context.iter.backward_search( "\\%s".printf( match_command ), 0, out c0, out c1, line_start ) )
        {
            var text = c1.get_text( context.iter );
            MatchInfo match_info;
            if( acceptance_pattern.match( text, 0, out match_info ) )
            {
                label_input_start = c1;
                label_input_start.forward_chars( 1 + match_info.fetch( 1 ).length );
                return true;
            }
        }
        return false;
    }

    public virtual void populate( Gtk.SourceCompletionContext context )
    {
        var proposals = new List< Gtk.SourceCompletionItem >();
        assert( editor.structure != null );
        var label_input = label_input_start.get_text( context.iter );
        editor.structure.search_feature( feature, ( node ) =>
            {
                var label = node.features[ feature ];
                if( label.has_prefix( label_input ) )
                {
                    var text = label;
                    if( context.iter.ends_line() || context.iter.get_char() != '}' ) text += "}";
                    proposals.append( new Gtk.SourceCompletionItem( label, text, null, null ) );
                }
                return true;
            }
        );
        context.add_proposals( this, proposals, true );
    }

}

