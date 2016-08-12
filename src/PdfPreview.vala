public abstract class PdfPreview : Gtk.Box
{

    private string? _pdf_path;
    public  string?  pdf_path { set { _pdf_path = value; reload(); } get { return _pdf_path; } }

    public abstract void reload(); 

}
