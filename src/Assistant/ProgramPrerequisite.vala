namespace Assistant
{

    public class ProgramPrerequisite : AbstractPrerequisite
    {

        public  string executable_name;
        public  string install_instructions;
        private Prerequisite.Status? status = null;

        public ProgramPrerequisite( string executable_name )
        {
            this.executable_name = executable_name;
        }

        public override Prerequisite.Status check_status()
        {
            if( executable_name.length == 0 )
            {
                warning( "Empty executable name is prerequisite" );
                return Prerequisite.Status.UNKNOWN;
            }
            status = Environment.find_program_in_path( executable_name ) != null ? Prerequisite.Status.FULFILLED : Prerequisite.Status.VIOLATED;
            return status;
        }
    
        public override string get_status_details()
        {
            if( status == null ) check_status();
            if( status == Prerequisite.Status.VIOLATED ) return install_instructions;
            else return "";
        }

        protected override string get_default_name()
        {
            return executable_name;
        }

    }

}

