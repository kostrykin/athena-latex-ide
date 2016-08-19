public class SourceFileView : Gtk.ScrolledWindow
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

    public weak SourceFileManager.SourceFile file { public get; private set; }
    public SourceStructure.SimpleNode structure { public get; private set; default = new SourceStructure.SimpleNode(); }

    public weak Editor editor { get; private set; }
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
        private SourceStructure.SimpleNode partition_root = new SourceStructure.SimpleNode();
        private SourceFileView view;

        internal Partition( SourceFileView view )
        {
            this.view = view;
            view.structure.add_child( partition_root );
        }

        /**
         * Removes this partition's nodes from the source structure graph.
         */
        ~Partition()
        {
            partition_root.remove_from_parents();
        }

        /**
         * Clears this partitions's source structure graph.
         */
        private void clear()
        {
            partition_root.remove_all_children();
        }

        private SourceAnalyzer.StringHandler create_leafs( SourceStructure.Feature feature )
        {
            return ( value ) =>
            {
                var leaf = new SourceStructure.Node();
                leaf.features[ feature ] = value;
                partition_root.add_child( leaf );
            };
        }

        private void handle_file_reference( string path, SourceAnalyzer.FileReferenceType type )
        {
            var ref_node = new SourceStructure.FileReferenceNode( view, path, type );
            partition_root.add_child( ref_node );
            ref_node.resolve();
        }
       
        /**
         * Rebuilds the source structure graph of this partition.
         */ 
        public override void update()
        {
            clear();
            var analyzer = SourceAnalyzer.instance;
            var text = get_text( view.buffer );

            analyzer.find_labels         ( text, create_leafs( SourceStructure.Feature.LABEL     ) );
            analyzer.find_bib_entries    ( text, create_leafs( SourceStructure.Feature.BIB_ENTRY ) );
            analyzer.find_file_references( text, handle_file_reference );
        }

        public override void split( SourcePartitioning.Partition successor )
        {
            successor.update();
            this.update();
        }

        public override void merge( SourcePartitioning.Partition successor )
        {
        }
    }

    #if DEBUG
    public static uint _debug_instance_counter = 0;
    #endif

    public SourceFileView( Editor editor, SourceFileManager.SourceFile file )
    {
        #if DEBUG
        ++_debug_instance_counter;
        #endif

        this.editor = editor;
        this.file = file;

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
        this.grab_focus.connect_after( () => { view.grab_focus(); } );
    }

    ~SourceFileView()
    {
        #if DEBUG
        --_debug_instance_counter;
        #endif
    }

    public override void destroy()
    {
        structure.remove_from_parents();
        partitioning = null;
        base.destroy();
    }

    /**
     * Returns the absolute counterpart if `path` is relative, or just `path` if it already is absolute.
     *
     * If `path` isn't absolute but its resolution fails, then `null` is returned.
     */
    public string? resolve_path( string path, SourceAnalyzer.FileReferenceType path_type )
    {
        if( ( path_type == SourceAnalyzer.FileReferenceType.SUB_REFERENCE )
         || ( path_type == SourceAnalyzer.FileReferenceType.UNKNOWN && !Path.is_absolute( path ) ) )
        {
            SourceFileManager.SourceFile? parent = null;
            if( editor.build_input != null ) parent = editor.build_input;
            else
            {
                if( this.file.path == null ) return null;
                else parent = this.file;
            }

            File root_dir = File.new_for_path( parent.path ).get_parent();
            var abs_path = root_dir.resolve_relative_path( path ).get_path();
            if( abs_path == null ) return null; // i.e. the path resolution failed
            return abs_path;
        }
        else
        {
            return path;
        }
    }

}
