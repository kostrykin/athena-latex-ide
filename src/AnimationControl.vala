public class AnimationControl
{

    public abstract class Animation
    {
        internal double duration;
        internal double time0;

        internal abstract void update( double progress );

        public signal void finished();
    }


    private Gee.List< Animation > animations = new Gee.LinkedList< Animation >();
    private uint fps;

    public AnimationControl( uint fps )
    {
        this.fps = fps;
    }

    private double now()
    {
        return ( GLib.get_real_time() / 1000 ) * 1e-3;;
    }

    public void start( Animation animation, double duration )
    {
        animation.duration = duration;
        animation.time0 = now();
        animations.insert( 0, animation );
        if( animations.size == 1 )
        {
            Timeout.add( 1000 / fps, update );
        }
    }

    private bool update()
    {
        var time = now();
        Animation?[] finished_animations = new Animation?[ animations.size ];
        int finished_animations_count = 0;
        foreach( var animation in animations )
        {
            var progress = Utils.mind( 1, ( time - animation.time0 ) / animation.duration );
            animation.update( progress );
            if( progress == 1 )
            {
                finished_animations[ finished_animations_count++ ] = animation;
            }
        }
        for( var animation_idx = 0; animation_idx < finished_animations_count; ++animation_idx )
        {
            var animation = finished_animations[ animation_idx ];
            animations.remove( animation );
            animation.finished();
        }
        invalidated();
        return animations.size > 0;
    }

    public Gee.Iterator< Animation > iterator()
    {
        return animations.iterator();
    }

    public uint count { get { return animations.size; } }

    public signal void invalidated();

}

