public class PopplerPreview : PdfPreview
{

    private PopplerDisplay display = new PopplerDisplay();
    private Gtk.Grid grid = new Gtk.Grid();

    public PopplerPreview()
    {
        Object( orientation: Gtk.Orientation.VERTICAL, spacing: 0 );

        grid.attach( display, 0, 0, 1, 1 );
        grid.attach( display.create_scrollbar( Gtk.Orientation.VERTICAL   ), 1, 0, 1, 1 );
        grid.attach( display.create_scrollbar( Gtk.Orientation.HORIZONTAL ), 0, 1, 1, 1 );

        display.set( "expand", true );
        pack_end( grid, true, true );
    }

    public override void reload()
    {
        display.pdf_path = pdf_path;
    }

}
