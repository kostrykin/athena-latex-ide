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
            buffer.move_mark( buffer.get_insert(), iter );
        }
        get
        {
            Gtk.TextIter iter;
            buffer.get_iter_at_mark( out iter, buffer.get_insert() );
            return iter.get_line();
        }
    }

    public SourceView( FileManager.File file )
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

        this.add( view );
    }

}
