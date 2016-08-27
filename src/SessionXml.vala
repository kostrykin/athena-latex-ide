public errordomain XmlError { CANT_OPEN_FILE, CANT_PARSE_XML, CANT_PARSE_SESSION }


public class SessionXml
{

    private static const string XML_NODE_SESSION = "session";
    private static const string XML_NODE_FILE    = "file";
    private static const string XML_NODE_BUILD   = "build";

    private static const string XML_ATTR_FILE_PATH   = "path";
    private static const string XML_ATTR_FILE_LINE   = "line";
    private static const string XML_ATTR_FILE_VIEW   = "view";
    private static const string XML_ATTR_FILE_MASTER = "master";
    private static const string XML_ATTR_FILE_ACTIVE = "active";

    private static const string XML_ATTR_BUILD_TYPE = "type";
    private static const string XML_ATTR_BUILD_PATH = "path";

    private Editor editor;

    public int build_type_position = 0;

    #if DEBUG
    public static uint _debug_instance_counter = 0;
    #endif

    public SessionXml( Editor editor )
    {
        #if DEBUG
        ++_debug_instance_counter;
        #endif

        this.editor = editor;
    }

    ~SessionXml()
    {
        #if DEBUG
        --_debug_instance_counter;
        #endif
    }

    public void write_to( string file_path )
    {
        var writer = new Xml.TextWriter.filename( file_path );
        writer.set_indent( true );
        writer.set_indent_string( "  " );

        writer.start_document();
        writer.start_element( XML_NODE_SESSION );

        foreach( var source_view in editor.get_source_views() )
        {
            var file = source_view.file;
            if( file.path == null ) continue;

            writer.start_element( XML_NODE_FILE );

            writer.write_attribute( XML_ATTR_FILE_PATH, file.path );
            writer.write_attribute( XML_ATTR_FILE_LINE, source_view.current_line.to_string() );
            writer.write_attribute( XML_ATTR_FILE_VIEW, source_view.view_position.to_string() );

            if( editor.session.master == file ) writer.write_attribute( XML_ATTR_FILE_MASTER, "on" );
            if( editor.current_file   == file ) writer.write_attribute( XML_ATTR_FILE_ACTIVE, "on" );

            writer.end_element(); // XML_NODE_FILE
        }

        writer.start_element( XML_NODE_BUILD );
        writer.write_attribute( XML_ATTR_BUILD_TYPE, build_type_position.to_string() );
        writer.write_attribute( XML_ATTR_BUILD_PATH, editor.session.output_path );
        writer.end_element(); // XML_NODE_BUILD

        writer.end_element(); // XML_NODE_SESSION
        writer.end_document();
        writer.flush();
    }

    public void read_from( string file_path ) throws XmlError
    {
        editor.close_all_files( false );
        var reader = new Xml.TextReader.filename( file_path );
        if( reader == null ) throw new XmlError.CANT_OPEN_FILE( "Failed to open %s", file_path );

        int read_result;
        Gee.Deque< XmlScope > scopes = new Gee.ArrayQueue< XmlScope >();
        scopes.offer_head( new XmlDocumentScope() );
        while( ( read_result = reader.read() ) == 1 && scopes.peek_head() != null )
        {
            if( reader.node_type() == Xml.ReaderType.END_ELEMENT )
            {
                scopes.poll_head().exit( this );
                continue;
            }
            if( reader.node_type() == Xml.ReaderType.SIGNIFICANT_WHITESPACE ) continue;

            var result = scopes.peek_head().process( this, reader.const_name(), reader );
            if( result != null ) scopes.offer_head( result );
        }
        Xml.Parser.cleanup();
        if( read_result != 0 || scopes.size != 1 ) throw new XmlError.CANT_PARSE_XML( "Failed to parse XML in %s", file_path );
    }

    private abstract class XmlScope
    {
        public abstract XmlScope? process( SessionXml loader, string node_name, Xml.TextReader reader ) throws XmlError;

        public virtual void exit( SessionXml loader )
        {
        }
    }

    private class XmlDocumentScope : XmlScope
    {
        public override XmlScope? process( SessionXml loader, string node_name, Xml.TextReader reader ) throws XmlError
        {
            switch( node_name )
            {

            case XML_NODE_SESSION:

                if( reader.node_type() == Xml.ReaderType.ELEMENT ) return new XmlSessionScope();
                else break;

            }
            throw new XmlError.CANT_PARSE_SESSION( "Unexpected occasion of \"%s\" in document scope", node_name );
        }
    }

    private class XmlSessionScope : XmlScope
    {
        private SourceFileManager.SourceFile? active;

        public override XmlScope? process( SessionXml loader, string node_name, Xml.TextReader reader ) throws XmlError
        {
            switch( node_name )
            {

            case XML_NODE_FILE:
                process_file( loader, reader );
                return null;

            case XML_NODE_BUILD:
                process_build( loader, reader );
                return null;

            }
            throw new XmlError.CANT_PARSE_SESSION( "Unexpected occasion of \"%s\" in session scope", node_name );
        }

        public override void exit( SessionXml loader )
        {
            if( active != null ) loader.editor.set_current_file_position( active.position );
        }

        private void process_file( SessionXml loader, Xml.TextReader reader ) throws XmlError
        {
            var path =               reader.get_attribute( XML_ATTR_FILE_PATH )  ;
            var line =    int.parse( reader.get_attribute( XML_ATTR_FILE_LINE ) );
            var view = double.parse( reader.get_attribute( XML_ATTR_FILE_VIEW ) );

            var master = reader.get_attribute( XML_ATTR_FILE_MASTER ) == "on";
            var active = reader.get_attribute( XML_ATTR_FILE_ACTIVE ) == "on";

            var file = loader.editor.open_file_from( path );
            if( file != null )
            {
                var file_view = loader.editor.get_source_view( file );
                file_view.current_line = line;
                Idle.add( () => { file_view.view_position = view; return false; } );

                if( active ) this.active = file;
                if( master ) loader.editor.session.master = file;
            }
        }

        private void process_build( SessionXml loader, Xml.TextReader reader ) throws XmlError
        {
            var path =            reader.get_attribute( XML_ATTR_BUILD_PATH )  ;
            var type = int.parse( reader.get_attribute( XML_ATTR_BUILD_TYPE ) );

            if( path.length > 0 ) loader.editor.session.output_path = path;
            loader.build_type_position = type;
        }
    }

}

