public class CellRendererTextConditional : Gtk.CellRendererText
{
    public delegate bool Condition();

    public Condition condition;

    public CellRendererTextConditional( Condition condition )
    {
        this.condition = condition;
    }

    public override void render( Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags )
    {
        if( this.condition() ) base.render( cr, widget, background_area, cell_area, flags );
    }
}

