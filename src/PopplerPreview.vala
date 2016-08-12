public class PopplerPreview : PdfPreview
{

    private PopplerDisplay display = new PopplerDisplay();

    public PopplerPreview()
    {
        Object( orientation: Gtk.Orientation.HORIZONTAL, spacing: 0 );
        pack_start( display, true, true );
        pack_end( display.create_scrollbar( Gtk.Orientation.VERTICAL ), false, false );
    }

    public override void reload()
    {
        display.pdf_path = pdf_path;
    }

}
