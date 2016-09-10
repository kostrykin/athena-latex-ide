namespace Assistant
{

    public interface FormValidator : Object
    {
        public abstract string associated_key { get; set; }

        public abstract bool ok { get; protected set; }

        public abstract void validate( FormPage form );
    }

    public abstract class BaseFormValidator : Object, FormValidator
    {
        public string associated_key { get; set; }
        public bool ok { get; protected set; }

        public abstract void validate( FormPage form );
    }

    namespace FormValidators
    {

        public class NonEmpty : BaseFormValidator
        {
            public override void validate( FormPage form )
            {
                ok = form[ associated_key ].length > 0;
            }
        }

    }

}

