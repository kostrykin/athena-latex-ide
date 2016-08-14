namespace Synctex
{

    namespace _impl_
    {
        [CCode (cname = "synctex_scanner_new_with_output_file")]
        extern void* scanner_new_with_output_file( string synctex_file_path, string build_dir_path, int parse );

        [CCode (cname = "synctex_scanner_free")]
        extern void scanner_free( void* scanner );

        [CCode (cname = "synctex_scanner_input")]
        extern void* scanner_input( void* scanner );

        [CCode (cname = "synctex_node_tag")]
        extern int node_tag( void* node );

        [CCode (cname = "synctex_scanner_get_name")]
        extern unowned string scanner_get_name( void* scanner, int tag );

        [CCode (cname = "synctex_node_sibling")]
        extern void* node_sibling( void* node );

        [CCode (cname = "synctex_display_query")]
        extern int display_query( void* scanner, string name, int line, int column );

        [CCode (cname = "synctex_next_result")]
        extern void* next_result( void* scanner );

        [CCode (cname = "synctex_node_page")]
        extern int node_page( void* node );

        [CCode (cname = "synctex_node_box_visible_h")]
        extern float node_box_visible_h( void* node );

        [CCode (cname = "synctex_node_box_visible_v")]
        extern float node_box_visible_v( void* node );

        [CCode (cname = "synctex_node_box_visible_width")]
        extern float node_box_visible_width( void* node );

        [CCode (cname = "synctex_node_box_visible_height")]
        extern float node_box_visible_height( void* node );

        [CCode (cname = "synctex_node_box_visible_depth")]
        extern float node_box_visible_depth( void* node );
    }

    /**
     * The wrapper classes are in another namespace to avoid name collisions in C code.
     */
    namespace Lib
    {
        public class Scanner
        {
            private void* scanner;

            public Scanner( string synctex_file_path, string? build_dir_path )
                ensures( scanner != null )
            {
                scanner = _impl_.scanner_new_with_output_file( synctex_file_path, build_dir_path, 1 );
            }

            ~Scanner()
            {
                if( scanner != null )
                {
                    _impl_.scanner_free( scanner );
                    scanner = null;
                }
            }

            public Node input()
            {
                return new Node( this, _impl_.scanner_input( scanner ) );
            }

            public unowned string get_name( int tag )
            {
                return _impl_.scanner_get_name( scanner, tag );
            }

            public int display_query( string name, int line, int column )
            {
                return _impl_.display_query( scanner, name, line, column );
            }

            public Node next_result()
            {
                return new Node( this, _impl_.next_result( scanner ) );
            }
        }

        public class Node
        {
            private void* node;

            /**
             * Back-reference to the `Scanner` object, to prevent it from
             * being garbage collected, which would also free the associated
             * node data, while the `Node` object is sitll alive.
             */
            private Scanner scanner;

            public Node( Scanner scanner, void* node )
            {
                this.scanner = scanner;
                this.node = node;
            }

            public bool valid   { get { return node != null; } }
            public int  tag     { get { return _impl_.node_tag( node ); } }
            public int  page    { get { return _impl_.node_page( node ); } }

            public void sibling()
            {
                node = _impl_.node_sibling( node );
            }

            public float box_visible_h      { get { return _impl_.node_box_visible_h( node ); } }
            public float box_visible_v      { get { return _impl_.node_box_visible_v( node ); } }
            public float box_visible_width  { get { return _impl_.node_box_visible_width( node ); } }
            public float box_visible_height { get { return _impl_.node_box_visible_height( node ); } }
            public float box_visible_depth  { get { return _impl_.node_box_visible_depth( node ); } }
        }
    }

}

