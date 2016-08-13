public class PopplerPreview : PdfPreview
{

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

        var zoom_toolitem = new Gtk.ToolItem();
        zoom_toolitem.add( zoom );
        zoom_toolitem.set_expand( true );
        toolbar.add( zoom_toolitem );

        zoom.set_value( display.zoom );
        zoom.value_changed.connect( () =>
            {
                display.zoom = zoom.get_value();
            }
        );

        toolbar.set_hexpand( true );
	pack_start( toolbar, false, false );
    }

}
