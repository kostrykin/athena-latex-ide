public class PopplerPreview : PdfPreview
{

    private static const double ZOOM_LEVEL_EPSILON = 0.1;
    private static const double ZOOM_STOPS[] = { 1.0 / 3, 1.0 / 2, 1, 1.5, 2, 2.5, 3, 4, 5 };

    private static Gtk.Image ICON_ZOOM_IN;
    private static Gtk.Image ICON_ZOOM_OUT;
    private static Gtk.Image ICON_ZOOM_ORIGINAL;
    private static Gtk.Image ICON_ZOOM_BEST_MATCH;

    static construct
    {
        ICON_ZOOM_IN         = new Gtk.Image.from_icon_name( "zoom-in-symbolic"      , MainWindow.TOOLBAR_ICON_SIZE );
        ICON_ZOOM_OUT        = new Gtk.Image.from_icon_name( "zoom-out-symbolic"     , MainWindow.TOOLBAR_ICON_SIZE );
        ICON_ZOOM_ORIGINAL   = new Gtk.Image.from_icon_name( "zoom-original-symbolic", MainWindow.TOOLBAR_ICON_SIZE );
        ICON_ZOOM_BEST_MATCH = new Gtk.Image.from_icon_name( "zoom-fit-best-symbolic", MainWindow.TOOLBAR_ICON_SIZE );
    }

    private PopplerDisplay display = new PopplerDisplay();
    private Gtk.Grid grid = new Gtk.Grid();
    private Gtk.Toolbar toolbar = new Gtk.Toolbar();
    private Gtk.Scale zoom = new Gtk.Scale.with_range( Gtk.Orientation.HORIZONTAL, 1.0 / 3, 5, 0.1 );

    public PopplerPreview()
    {
        Object( orientation: Gtk.Orientation.VERTICAL, spacing: 0 );

        grid.attach( display, 0, 0, 1, 1 );
        grid.attach( display.create_scrollbar( Gtk.Orientation.VERTICAL   ), 1, 0, 1, 1 );
        grid.attach( display.create_scrollbar( Gtk.Orientation.HORIZONTAL ), 0, 1, 1, 1 );

        display.set( "expand", true );
        pack_end( grid, true, true );
        setup_toolbar();
    }

    public override void reload()
    {
        display.pdf_path = pdf_path;
    }

    private void setup_toolbar()
    {
        toolbar.set_icon_size( MainWindow.TOOLBAR_ICON_SIZE );

        var btn_zoom_best_match = new Gtk.ToolButton( ICON_ZOOM_BEST_MATCH, null );
        toolbar.add( btn_zoom_best_match );
        btn_zoom_best_match.clicked.connect( zoom_best_match );
        btn_zoom_best_match.show();

        var btn_zoom_original = new Gtk.ToolButton( ICON_ZOOM_ORIGINAL, null );
        toolbar.add( btn_zoom_original );
        toolbar.add( new Gtk.SeparatorToolItem() );
        btn_zoom_original.clicked.connect( zoom_original );
        btn_zoom_original.show();

        var btn_zoom_out = new Gtk.ToolButton( ICON_ZOOM_OUT, null );
        toolbar.add( btn_zoom_out );
        btn_zoom_out.clicked.connect( zoom_out );
        btn_zoom_out.show();

        var zoom_toolitem = new Gtk.ToolItem();
        zoom_toolitem.add( zoom );
        zoom_toolitem.set_expand( true );
        toolbar.add( zoom_toolitem );

        var btn_zoom_in = new Gtk.ToolButton( ICON_ZOOM_IN, null );
        toolbar.add( btn_zoom_in );
        btn_zoom_in.clicked.connect( zoom_in );
        btn_zoom_in.show();

        zoom.clear_marks();
        zoom.set_draw_value( false );
        zoom.set_has_origin( false );
        zoom.set_value( display.zoom );
        zoom.value_changed.connect( () =>
            {
                display.zoom = zoom.get_value();
            }
        );

        var busy_toolitem = new Gtk.ToolItem();
        var busy_view = new LoadingIndicator( MainWindow.TOOLBAR_ICON_SIZE );
        busy_toolitem.add( busy_view );
        busy_toolitem.show_all();
        toolbar.add( new Gtk.SeparatorToolItem() );
        toolbar.add( busy_toolitem );

        busy_view.fade_out( LoadingIndicator.FADE_IMMEDIATELY );
        display.renderer_started .connect( () => { busy_view.fade_in ( 5.0 ); } );
        display.renderer_finished.connect( () => { busy_view.fade_out( 1.0 ); } );

        toolbar.set_hexpand( true );
	pack_start( toolbar, false, false );
    }

    /**
     * Reduces the current zoom level to the next-lowest zoom stop.
     */
    public void zoom_out()
    {
        for( int i = ZOOM_STOPS.length - 1; i >= 0; --i )
        {
            if( ZOOM_STOPS[ i ] + ZOOM_LEVEL_EPSILON * ZOOM_STOPS[ i ] < display.zoom )
            {
                zoom.adjustment.value = ZOOM_STOPS[ i ];
                break;
            }
        }
    }

    /**
     * Increases the current zoom level to the next-highest zoom stop.
     */
    public void zoom_in()
    {
        for( int i = 0; i < ZOOM_STOPS.length; ++i )
        {
            if( ZOOM_STOPS[ i ] - ZOOM_LEVEL_EPSILON * ZOOM_STOPS[ i ] > display.zoom )
            {
                zoom.adjustment.value = ZOOM_STOPS[ i ];
                break;
            }
        }
    }

    public void zoom_original()
    {
        zoom.adjustment.value = 1;
    }

    public void zoom_best_match()
    {
        zoom.adjustment.value = display.best_match_zoom_level;
    }

}
