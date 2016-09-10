namespace Assistant
{

    public errordomain PrerequisiteError { NOT_FIXABLE }

    public interface Prerequisite : Object
    {
        public enum Status { FULFILLED, VIOLATED, UNKNOWN }

        public abstract void invalidate_status();

        public abstract Status get_status();
    
        public abstract string get_status_details();

        public signal void status_details_changed();

        public abstract string get_name();
    
        public abstract bool is_fixable();
    
        public abstract async void fix() throws PrerequisiteError; // see: https://wiki.gnome.org/Projects/Vala/Tutorial#Asynchronous_Methods

        public abstract Context context { get; protected set; }
    }

    public abstract class AbstractPrerequisite : Object, Prerequisite
    {

        public string? name_override = null;
        private Prerequisite.Status? status = null;
        public Context context { get; protected set; }

        public AbstractPrerequisite( Context context )
        {
            this.context = context;
        }

        public void invalidate_status()
        {
            status = null;
        }

        private int get_status_recursion_level = 0;

        public Prerequisite.Status get_status()
            requires( get_status_recursion_level < 3 )
        {
            ++get_status_recursion_level;
            if( get_status_recursion_level > 1 ) while( status == null ) Gtk.main_iteration();
            if( status == null )
            {
                bool is_thread_running = true;
                ThreadFunc< void* > run = () =>
                {
                    var new_status = check_status();
                    Idle.add( () =>
                        {
                            status = new_status;
                            is_thread_running = false;
                            return false;
                        }
                    );
                    return null;
                };
                Thread.create< void* >( run, false );

                do Gtk.main_iteration();
                while( is_thread_running );
            }
            --get_status_recursion_level;
            return status;
        }

        protected abstract Prerequisite.Status check_status();
    
        public abstract string get_status_details();

        public string get_name()
        {
            return name_override ?? get_default_name();
        }

        protected abstract string get_default_name();

        public virtual bool is_fixable()
        {
            return false;
        }
    
        public virtual async void fix() throws PrerequisiteError
        {
            if( !is_fixable() ) throw new PrerequisiteError.NOT_FIXABLE( "Cannot be fixed automatically" );
        }

    }

}

