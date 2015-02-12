package Treex::Tool::TranslationModel::Common;
use Treex::Core::Common;
use utf8;
use List::Util qw(sum);
use Class::Std;

sub predict {
    my ( $self, $input_label ) = @_;
    my ($first_translation) = $self->get_translations($input_label);
    if ( defined $first_translation ) {
        return $first_translation->{label};
    }
    else {
        return undef;
    }
}

sub get_translations {
    my $self = shift;
    my @t = $self->get_unnormalized_translations(@_) or return;
    my $sum = sum map {$_->{prob}} @t;
    if ($sum != 1){
        for my $translation (@t){
            $translation->{prob} /= $sum;
        }
    }
    return @t;
}

sub get_unnormalized_translations {
    log_fatal("get_unnormalized_translation() is not (and could not be) implemented"
        . " in the abstract class Treex::Tool::TranslationModel::Common !");
}

1;

__END__


=head1 NAME

TranslationModel::Common

=head1 DESCRIPTION

'Abstract class' ancestor of all translation models.

=head1 COPYRIGHT

Copyright 2010 Martin Popel
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
