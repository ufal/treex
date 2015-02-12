package Treex::Tool::TranslationModel::Derivative::Common;
use Treex::Core::Common;
use Class::Std;

use base qw(Treex::Tool::TranslationModel::Common);


{
    our $VERSION = '0.01';

    our %base_model : ATTR;

    sub BUILD {
        my ( $self, $ident, $arg_ref ) = @_;
        $base_model{$ident} = $arg_ref->{base_model}
            or log_fatal "'base_model' must be defined";
        return $self;
    }

    sub get_base_model {
        my ($self) = @_;
        return $base_model{ident $self};
    }

}


1;

__END__


=head1 NAME

TranslationModel::Derivative::Common


=head1 DESCRIPTION

'Abstract class' ancestor of derivative translation models.

=head1 COPYRIGHT

Copyright 2009 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
