using Cairo;


namespace Drawables
{

    public abstract class Shape
    {
    
        public Utils.RectD? bounding_box { public get; protected set; default = null; }
        public double opacity = 1;
    
        public Shape()
        {
            this.with_bounding_box( null );
        }
    
        public Shape.with_bounding_box( Utils.RectD? bounding_box )
        {
            this.bounding_box = bounding_box;
        }
    
        public abstract void draw( Context cr );
    
        public virtual bool is_visible( Utils.RectD visible_area )
        {
            if( bounding_box == null )
            {
                return true;
            }
            else
            {
                return !bounding_box.is_disjoint( visible_area );
            }
        }
    
    }
    
    
    public class Box : Shape
    {
    
        public Utils.RectD rect;
        public double r;
        public double g;
        public double b;
        public double a;
        public double border_width;
        public double border_alpha;
    
        public Box( Utils.RectD rect, double r, double g, double b, double a, double border_width, double border_alpha )
        {
            base.with_bounding_box( rect );
            this.rect = rect;
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
            this.border_width = border_width;
            this.border_alpha = border_alpha;
        }
    
        public override void draw( Context cr )
        {
            cr.rectangle( rect.x, rect.y, rect.w, rect.h );
            cr.set_source_rgba( r, g, b, a * opacity );
            cr.fill_preserve();
            cr.set_line_width( border_width );
            cr.set_source_rgba( r, g, b, border_alpha * opacity );
            cr.stroke();
        }
    
    }

}

