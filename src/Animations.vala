namespace Animations
{

    public class FadeOut : AnimationControl.Animation
    {
        private Drawables.Shape shape;

        public FadeOut( Drawables.Shape shape )
        {
            this.shape = shape;
        }

        internal override void update( double progress )
        {
            shape.opacity = Math.sqrt( 1 - progress );
        }
    }


    public class Interpolation : AnimationControl.Animation
    {
        public delegate double Func( double value );
        public Func? non_linearity;

        public delegate void Callback( double[] state );
        private Callback callback;

        private double[] state0;
        private double[] state_change;
        private double[] state;

        public Interpolation( double[] state0, double[] state1, Callback callback, Func? non_linearity = null )
            requires( state0.length == state1.length )
        {
            this.non_linearity = non_linearity;
            this.callback = callback;
            this.state0 = state0;
            this.state_change = new double[ state0.length ];
            this.state = new double[ state0.length ];
            for( int i = 0; i < state.length; ++i )
            {
                this.state_change[ i ] = state1[ i ] - state0[ i ];
            }
        }

        internal override void update( double progress )
        {
            var loc = non_linearity == null ? progress : non_linearity( progress );
            for( int i = 0; i < state.length; ++i )
            {
                state[ i ] = state0[ i ] + loc * state_change[ i ];
            }
            callback( state );
        }
    }

}
