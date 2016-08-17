public class SourcePartitioning
{

    public Gtk.TextBuffer buffer { public get; private set; }

    public class LineMark
    {
        public int line { public get; internal set; }

        public LineMark( int line )
        {
            this.line = line;
        }
    }

    private Gee.MultiMap< int, LineMark > marks = new Gee.TreeMultiMap< int, LineMark >( ( a, b ) => { return b - a; } );

    public SourcePartitioning( Gtk.TextBuffer buffer, owned PartitionFactory partition_factory )
    {
        this.buffer = buffer;
        this.partition_factory = (owned) partition_factory;

        /* Wait for the control to return to the event loop before partitioning
         * and installing the buffer callbacks, to avoid re-partitioning e.g.
         * after something is loaded into the buffer.
         */
        Timeout.add( 0, () =>
            {
                buffer.insert_text.connect_after( ( ref end, text, text_length ) =>
                    {
                        Gtk.TextIter start = Gtk.TextIter();
                        start.assign( end );
                        start.backward_chars( text_length );
                        update_with_start_end( start, end, true );
                    }
                );
                buffer.delete_range.connect( ( start, end ) =>
                    {
                        update_with_start_end( start, end, false );
                    }
                );
                partition( DEFAULT_LINES_PER_PARTITION, true );
                return GLib.Source.REMOVE;
            }
        );
    }

    private void update_with_start_end( Gtk.TextIter start, Gtk.TextIter end, bool insert )
    {
        int line_breaks = end.get_line() - start.get_line();
        int line0 = start.get_line();
        
        /* We wait with the update until the control returns to the event loop,
         * in order to ensure, that the updates have been committed to the buffer.
         */
        Timeout.add( 0, () =>
            {
                shift_marks( line0, line_breaks * ( insert ? 1 : -1 ) );
                update( line0, 1 + line_breaks );
                return GLib.Source.REMOVE;
            }
        );
    }

    private void shift_marks( int line0, int lines )
    {
        if( lines != 0 )
        {
            var affected_marks = new LineMark[ marks.size ];
            int affected_marks_count = 0;
            foreach( var mark in marks.get_values() )
            {
                if( mark.line > line0 ) affected_marks[ affected_marks_count++ ] = mark;
            }
            for( int i = 0; i < affected_marks_count; ++i )
            {
                var mark = affected_marks[ i ];
                marks.remove( mark.line, mark );
                mark.line += lines;
                marks[ mark.line ] = mark;
            }
        }
    }

    public static const int DEFAULT_LINES_PER_PARTITION              = 10;
    public static const int     MAX_LINES_PER_PARTITION_AFTER_MERGE  = 15;
    public static const int     MIN_LINES_PER_PARTITION_BEFORE_SPLIT = 19;

    public abstract class Partition
    {
        public LineMark start { public get; internal set; } ///< Marks the first line of this partition (inclusive).
        public LineMark end   { public get; internal set; } ///< Marks the last line of this partition (exclusive).

        public int line_count { get { return end.line - start.line; } }

        public string get_text( Gtk.TextBuffer buffer )
        {
            Gtk.TextIter start_iter, end_iter;
            buffer.get_iter_at_line( out start_iter, start.line );
            if( end.line < buffer.get_line_count() )
            {
                buffer.get_iter_at_line( out end_iter, end.line );
            }
            else
            {
                buffer.get_end_iter( out end_iter );
            }
            return start_iter.get_text( end_iter );
        }

        /**
         * Destroys the partition.
         *
         * Only called, if the partition isn't merged into another one.
         */
        public abstract void destroy();
        
        /**
         * Updates the partition.
         */
        public abstract void update();

        /**
         * Indicates, that `successor` has been split of from `this` partition.
         *
         * The `successor` always is a newly created partition.
         */
        public abstract void split( Partition successor );

        public abstract void merge( Partition successor );
    }

    public delegate Partition PartitionFactory();
    public PartitionFactory partition_factory;

    private Partition new_partition( LineMark start, LineMark end )
    {
        var p = partition_factory();
        p.start = start;
        p.end = end;
        return p;
    }

    private Gee.List< Partition? > partitions = new Gee.LinkedList< Partition? >();

    public void partition( int lines_per_partition, bool run_update )
    {
        foreach( var p in partitions ) p.destroy();
        partitions.clear();
        marks.clear();

        var start = new LineMark( 0 );
        marks[ start.line ] = start;
        for( int line = 0; line <= buffer.get_line_count(); ++line )
        {
            if( line - start.line > lines_per_partition )
            {
                var p = new_partition( start, new LineMark( line ) );
                partitions.add( p );
                marks[ p.end.line ] = p.end;
                start = p.end;
            }
        }

        if( start.line < buffer.get_line_count() )
        {
            var end = new LineMark( buffer.get_line_count() );
            partitions.add( new_partition( start, end ) );
            marks[ end.line ] = end;
        }

        if( run_update ) foreach( var p in partitions ) p.update();
    }

    private void update( int first_affected_line, int affected_line_count )
    {
        Partition[] invalidated_partitions = new Partition[ partitions.size ];
        int invalidated_partitions_count = 0;
        foreach( var p in partitions )
        {
            if( p.start.line <= first_affected_line && p.start.line + affected_line_count <= p.end.line )
            {
                invalidated_partitions[ invalidated_partitions_count++ ] = p;
            }
        }

        if( affected_line_count > 1 )
        {
            var partitions_to_update = new Gee.HashSet< Partition >();

            /* First, perform those split, which are necessary.
             * Don't update any partitions yet, as they still may be merged later.
             */
            var p_iter = partitions.list_iterator();
            for( int i = 0; i < invalidated_partitions_count; ++i )
            {
                Partition p1 = null;
                Partition p0 = invalidated_partitions[ i ];
                partitions_to_update.add( p0 );
                if( split_partition( p_iter, p0, out p1 ) )
                {
                    p0.split( p1 );
                    partitions_to_update.add( p1 );
                }
            }

            merge_partitions( partitions_to_update );

            foreach( var p in partitions_to_update ) p.update();
        }
        else
        {
            /* Since only one line was affected,
             * also exactly one partition was invalidated.
             */
            invalidated_partitions[ 0 ].update();
        }
    }

    private bool split_partition( Gee.ListIterator< Partition > p_iter, Partition p0, out Partition p1 )
    {
        int lines = p0.end.line - p0.start.line;
        if( lines > MIN_LINES_PER_PARTITION_BEFORE_SPLIT )
        {
            int lines0 = Utils.max( 1, lines / 2 );
            int lines1 = lines - lines0;
            assert( lines1 >= 1 );

            p1 = new_partition( new LineMark( p0.start.line + lines0 ), p0.end );
            p0.end = p1.start;
            marks[ p1.start.line ] = p1.start;

            /* Move an iterator to the position of `p0` and insert `p1` behind.
             */
            while( p_iter.next() && p_iter.@get() != p0 );
            p_iter.add( p1 );
            return true;
        }
        else
        {
            return false;
        }
    }

    private void merge_partitions( Gee.Set< Partition > partitions_to_update )
    {
        var p1_iter = partitions.iterator();
        p1_iter.next();
        Partition p0 = p1_iter.@get();

        while( p1_iter.next() )
        {
            Partition p1 = p1_iter.@get();

            if( p0.line_count + p1.line_count <= MAX_LINES_PER_PARTITION_AFTER_MERGE )
            {
                p0.end = p1.end;
                p0.merge( p1 );
                p1_iter.remove();
                partitions_to_update.remove( p1 );
            }

            p0 = p1;
        }
    }

}
