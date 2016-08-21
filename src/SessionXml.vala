public class SessionXml
{

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
        writer.start_element( "session" );

        foreach( var source_view in editor.get_source_views() )
        {
            var file = source_view.file;
            if( file.path == null ) continue;

            writer.start_element( "file" );

            writer.write_attribute( "path", file.path );
            writer.write_attribute( "line", source_view.current_line.to_string() );
            writer.write_attribute( "view", source_view.view_position.to_string() );

            if( editor.session.master == file ) writer.write_attribute( "master", "on" );
            if( editor.current_file   == file ) writer.write_attribute( "active", "on" );

            writer.end_element(); // file
        }

        writer.start_element( "build" );
        writer.write_attribute( "type", build_type_position.to_string() );
        writer.write_attribute( "path", editor.session.output_path );
        writer.end_element(); // build 

        writer.end_element(); // session
        writer.end_document();
        writer.flush();
    }

    public void read_from( string file_path )
    {
        editor.close_all_files( false );
    }

}

