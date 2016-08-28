namespace Assistant
{

    public errordomain PrerequisiteError { NOT_FIXABLE }

    public interface Prerequisite : Object
    {
    
        public enum Status { FULFILLED, VIOLATED, UNKNOWN }
    
        public abstract Status check_status();
    
        public abstract string get_status_details();

        public abstract string get_name();
    
        public abstract bool is_fixable();
    
        public abstract async void fix() throws PrerequisiteError; // see: https://wiki.gnome.org/Projects/Vala/Tutorial#Asynchronous_Methods
    
    }

    public abstract class AbstractPrerequisite : Object, Prerequisite
    {

        public string? name_override = null;

        public abstract Prerequisite.Status check_status();
    
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

