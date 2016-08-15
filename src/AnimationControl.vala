public class AnimationControl
{

    public abstract class Animation
    {
        public enum State { PENDING, RUNNING, STOPPED }
        public State state { public get; internal set; default = State.PENDING; }

        internal double duration;
        internal double time0;

        internal abstract void update( double progress );

        /**
         * Indicates, that the animation has finished regularily.
         */
        public signal void finished();

        /**
         * Stops the animation without further notifications.
         * Neither its `update` method will be called hereinafter,
         * nor will it emit its `finished` signal.
         */
        public void kill()
        {
            state = State.STOPPED;
        }
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

    /**
     * Starts the `animation` if it wasn't started yet.
     *
     * The post-condition is always satisfied, because the animation isn't
     * updated until the execution control returns to the event loop.
     */
    public void start( Animation animation, double duration )
        requires( animation.state == Animation.State.PENDING )
        ensures ( animation.state == Animation.State.RUNNING )
    {
        animation.state = Animation.State.RUNNING;
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
            /* Update the animation, only if it is still running.
             */
            if( animation.state == Animation.State.RUNNING )
            {
                var progress = Utils.mind( 1, ( time - animation.time0 ) / animation.duration );
                animation.update( progress );

                /* Proceed with next animation, if this animation isn't finished yet.
                 */
                if( progress < 1 ) continue;
            }

            /* The animation is either stopped or finished.
             * We will remove it in a moment.
             */
            finished_animations[ finished_animations_count++ ] = animation;
        }

        /* Remove all finished or stopped animations.
         */
        for( var animation_idx = 0; animation_idx < finished_animations_count; ++animation_idx )
        {
            var animation = finished_animations[ animation_idx ];
            animations.remove( animation );

            /* Only emit the `finished` signal, if the animation isn't stopped yet.
             * This happens if the animation is stopped manually instead of finishing regularily.
             */
            if( animation.state != Animation.State.STOPPED )
            {
                animation.state = Animation.State.STOPPED;
                animation.finished();
            }
        }

        /* Notify observers and keep the timeout only alive, if there are running animations left.
         */
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

