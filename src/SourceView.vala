class SourceView : Gtk.ScrolledWindow
{

    static construct
    {
        string font_name = new GLib.Settings( "org.gnome.desktop.interface" ).get_string( "monospace-font-name" );
        DEFAULT_FONT = Pango.FontDescription.from_string( font_name );

        LANGUAGE     = Gtk.SourceLanguageManager.get_default().get_language( "latex" );
        STYLE_SCHEME = Gtk.SourceStyleSchemeManager.get_default().get_scheme( "solarized-light" );
    }

    private static Pango.FontDescription DEFAULT_FONT;
    private static Gtk.SourceLanguage    LANGUAGE;
    private static Gtk.SourceStyleScheme STYLE_SCHEME;

    public FileManager.File file { public get; private set; }
    public SourceStructure.InnerNode structure { public get; private set; default = new SourceStructure.InnerNode(); }

    private Gtk.SourceView view;

    public Gtk.TextBuffer buffer
    {
        get
        {
            return view.buffer;
        }
    }

    public static string[] available_style_schemes
    {
        get
        {
            return Gtk.SourceStyleSchemeManager.get_default().get_scheme_ids();
        }
    }

    public int current_line
    {
        set
        {
            Gtk.TextIter iter;
            buffer.get_iter_at_mark( out iter, buffer.get_insert() );
            iter.set_line( value );
            buffer.place_cursor( iter );
            view.scroll_to_iter( iter, 0, true, 0.5, 0.5 );
        }
        get
        {
            Gtk.TextIter iter;
            buffer.get_iter_at_mark( out iter, buffer.get_insert() );
            return iter.get_line();
        }
    }

    private SourcePartitioning partitioning;

    private class Partition : SourcePartitioning.Partition
    {
        internal SourceStructure.InnerNode node = new SourceStructure.InnerNode();
        internal Gtk.TextBuffer buffer;

        internal Partition( SourceView view )
        {
            this.buffer = view.buffer;
            view.structure.add_child( node );
        }

        public override void destroy()
        {
            node.remove_from_parent();
        }

        private SourceAnalyzer.StringHandler create_leafs( SourceStructure.Feature feature )
        {
            return ( value ) =>
            {
                var leaf = new SourceStructure.Node();
                leaf.features[ feature ] = value;
                node.add_child( leaf );
                return true;
            };
        }
        
        public override void update()
        {
            node.remove_all_children();
            var analyzer = SourceAnalyzer.instance;
            var text = get_text( buffer );

            analyzer.find_labels     ( text, create_leafs( SourceStructure.Feature.LABEL     ) );
            analyzer.find_bib_entries( text, create_leafs( SourceStructure.Feature.BIB_ENTRY ) );
            // TODO: find file references
        }

        public override void split( SourcePartitioning.Partition successor )
        {
            successor.update();
            this.update();
        }

        public override void merge( SourcePartitioning.Partition successor )
        {
            successor.destroy();
        }
    }

    public SourceView( Editor editor, FileManager.File file )
    {
        var buffer = new Gtk.SourceBuffer.with_language( LANGUAGE );
        buffer.set_style_scheme( STYLE_SCHEME );

        view = new Gtk.SourceView();
        view.buffer = buffer;
	view.show_line_marks = true;
	view.highlight_current_line = true;
        view.tab_width = 4;
        view.override_font( DEFAULT_FONT );
        view.set_auto_indent( true );
        view.set_show_line_numbers( true );
        view.set_wrap_mode( Gtk.WrapMode.WORD_CHAR );

        partitioning = new SourcePartitioning( buffer, () => { return new Partition( this ); } );
        view.get_completion().add_provider( new ReferenceCompletionProvider( editor ) );

        this.add( view );
    }

}
