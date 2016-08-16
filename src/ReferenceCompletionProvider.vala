public class ReferenceCompletionProvider: Object, Gtk.SourceCompletionProvider
{

    private weak Editor editor;
    private Regex acceptance_pattern;

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
            return acceptance_pattern.match_all( text );
        }
        return false;
    }

    public virtual void populate( Gtk.SourceCompletionContext context )
    {
        var proposals = new List< Gtk.SourceCompletionItem >();
        assert( editor.structure != null );
        editor.structure.search_feature( SourceStructure.Feature.LABEL, ( node ) =>
            {
                var label = node.features[ SourceStructure.Feature.LABEL ];
                proposals.append( new Gtk.SourceCompletionItem( label, label + "}", null, null ) ); // FIXME: only append `}` if it isn't already there
                return true;                                               // FIXME: there might already be text after the `{` which we must not repeat
            }
        );
        context.add_proposals( this, proposals, true );
    }

}

