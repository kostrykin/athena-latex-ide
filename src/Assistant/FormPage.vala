namespace Assistant
{

    public class FormPage : Gtk.Grid, Page
    {

        private AssistantWindow? assistant;
        private string name;
        private Gee.Map< string, string > values = new Gee.HashMap< string, string >();
        private int last_line = -1;

        public FormPage( string name )
        {
            Object();
            this.name = name;

            column_spacing = 10;
               row_spacing = 10;
        }

        private Gee.List< FormValidator > validators = new Gee.ArrayList< FormValidator >();

        private int append_new( string key, string label, FormValidator? validator, bool align_label_center = true )
        {
            var label_view = new Gtk.Label( label );
            label_view.ellipsize = Pango.EllipsizeMode.END;
            label_view.set_alignment( 0, align_label_center ? 0.5f : 0f );
            label_view.show();
            attach( label_view, 0, ++last_line, 1, 1 );

            if( validator != null )
            {
                validator.associated_key = key;
                validators.add( validator );
            }

            return last_line;
        }

        private void process_validator( FormValidator? validator )
        {
            if( validator != null )
            {
                validator.validate( this );
                completed( this, is_complete() );
            }
        }

        public void append_entry( string key, string label, FormValidator? validator, string default_value = "" )
            requires( ( key in values.keys ) == false )
            ensures ( ( key in values.keys ) == true  )
        {
            var line = append_new( key, label, validator );
            var entry = new Gtk.Entry();
            entry.hexpand = true;
            entry.text = default_value;
            attach( entry, 1, line, 1, 1 );

            string entry_key = key;
            entry.changed.connect( () =>
                {
                    values[ entry_key ] = entry.text;
                    assistant.set_summary_line( label, values[ entry_key ] );
                    process_validator( validator );
                }
            );
            entry.changed();
            entry.show();
        }

        public void append_text_view( string key, string label, FormValidator? validator )
            requires( ( key in values.keys ) == false )
            ensures ( ( key in values.keys ) == true  )
        {
            var line   = append_new( key, label, validator, false );
            var scroll = new Gtk.ScrolledWindow( null, null );
            var view   = new Gtk.TextView();
            view.hexpand = true;
            scroll.add( view );
            attach( scroll, 1, line, 1, 1 );

            string entry_key = key;
            view.buffer.changed.connect( () =>
                {
                    values[ entry_key ] = view.buffer.text;
                    assistant.set_summary_line( label, values[ entry_key ] );
                    process_validator( validator );
                }
            );
            view.buffer.changed();
            scroll.show_all();
        }

        public string get( string key )
            requires( ( key in values.keys ) == true )
        {
            return values[ key ];
        }

        public void prepare()
        {
        }

        public string get_name()
        {
            return name;
        }

        public bool is_complete()
        {
            if( last_line == -1 ) return false;
            foreach( var validator in validators ) if( !validator.ok ) return false;
            return true;
        }

        public void set_assistant( AssistantWindow? assistant )
        {
            this.assistant = assistant;
        }

    }

}

