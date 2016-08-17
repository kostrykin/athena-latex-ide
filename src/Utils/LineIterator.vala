namespace Utils
{

    public class LineIterator
    {

        private string text;
        private int start;
        private int end = -1;

        /**
         * Constructs a new iterator, which points to the imaginary line before the first line.
         */
        public LineIterator( string text )
        {
            this.text = text;
        }

        /**
         * Moves on to the next line and returns `true`. Returns `false` if there is no next line.
         */
        public bool next()
        {
            start = end + 1;
            if( start <= text.length )
            {
                end = text.index_of_char( '\n', start );
                if( end == -1 ) end = text.length;
                return true;
            }
            else return false;
        }

        public bool valid { get { return end > -1 && start + 1 < text.length; } }

        /**
         * References the current line, without the end-line character at the end.
         */
        public string @get()
        {
            return text[ start : end ];
        }

    }

    public struct line_wise
    {

        private string text;

        public line_wise( string text )
        {
            this.text = text;
        }

        public LineIterator iterator()
        {
            return new LineIterator( text );
        }

    }

}
