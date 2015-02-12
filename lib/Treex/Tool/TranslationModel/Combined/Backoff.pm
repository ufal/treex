package Treex::Tool::TranslationModel::Combined::Backoff;
use Treex::Core::Common;
use Class::Std;
use Storable;

{
    our $VERSION = '0.01';

    our %sequence_of_models : ATTR;

    sub BUILD {
        my ( $self, $ident, $arg_ref ) = @_;
        if ($arg_ref->{models}) {
            $sequence_of_models{ident $self} = $arg_ref->{models};
            log_info "Backoff translation model with ".scalar(@{$arg_ref->{models}})." models initialized.";
        }
        else {
            log_fatal "A sequence of models must be specified!";
        }
        return $self;
    }


    sub get_translations {
        my ($self, $input_label, $features_rf) = @_;

        my $model_number = 1;
        foreach my $model (@{$sequence_of_models{ident $self}}) {
            if (my @translations = $model->get_translations($input_label, $features_rf)) {
#                print "success $model_number\n";
                return @translations;
            }
            $model_number++;
        }
        return ();

    }

    sub predict {
        my ($self, $input_label) = @_;
        my ($first_translation) = $self->get_translations($input_label);
        if (defined $first_translation) {
            return $first_translation->{label};
        }
        else {
            return undef;
        }
    }


}



1;

__END__


=head1 NAME

TranslationModel::Combined::Backoff


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2009 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
