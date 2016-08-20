public class ReferenceCompletionProvider: Object, Gtk.SourceCompletionProvider
{

    private weak Editor editor;
    private Regex acceptance_pattern;
    private Gtk.TextIter label_input_start;

    public ReferenceCompletionProvider( Editor editor )
    {
        this.editor = editor;
        this.acceptance_pattern = new Regex( "[A-Za-z0-9_:]*$", RegexCompileFlags.ANCHORED | RegexCompileFlags.DOLLAR_ENDONLY );
    }

    public virtual string get_name()
    {
        return "Labels";
    }

    public virtual bool match( Gtk.SourceCompletionContext context )
    {
        Gtk.TextIter line_start = Gtk.TextIter();
        line_start.assign( context.iter );
        line_start.set_line_offset( 0 );

        Gtk.TextIter c0, c1;
        if( context.iter.backward_search( "\\ref{", 0, out c0, out c1, line_start ) )
        {
            var text = c1.get_text( context.iter );
            if( acceptance_pattern.match_all( text ) )
            {
                label_input_start = c1;
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
        editor.structure.search_feature( SourceStructure.Feature.LABEL, ( node ) =>
            {
                var label = node.features[ SourceStructure.Feature.LABEL ];
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

