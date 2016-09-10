namespace Assistant
{

    public interface ProjectType : Object
    {
        public abstract void prepare( Context context );

        public abstract void activate( AssistantWindow assistant );
        public abstract void withdraw( AssistantWindow assistant );

        public abstract string get_name();
        public abstract string get_description();
    }

    public class SimpleProjectType : Object, ProjectType
    {

        private string name;
        public  string description;
        public weak Context? context { get; private set; default = null; }

        public SimpleProjectType( string name, string description = "" )
        {
            this.name = name;
            this.description = description;
        }

        public virtual void prepare( Context context )
        {
            this.context = context;
        }

        public string get_name()
        {
            return name;
        }

        public string get_description()
        {
            return description;
        }

        private Gee.List< Page > pages = new Gee.ArrayList< Page >();

        public bool activated { get; private set; default = false; }

        public void add_page( Page page ) requires( !activated )
        {
            pages.add( page );
        }

        public void remove_page( Page page ) requires( !activated )
        {
            pages.remove( page );
        }

        public void activate( AssistantWindow assistant ) requires( !activated ) ensures( activated )
        {
            activated = true;
            for( int page_idx = 0; page_idx < pages.size; ++page_idx )
            {
                var page = pages[ page_idx ];
                assistant.append_page( page );
                page.show_all();
            }
        }

        public void withdraw( AssistantWindow assistant ) requires( activated ) ensures( !activated )
        {
            activated = false;
            for( int page_idx = pages.size - 1; page_idx >= 0; --page_idx ) assistant.remove_page( 1 + page_idx );
        }

    }

}

