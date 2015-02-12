package Treex::Tool::TranslationModel::Derivative::CS2RU::ReflexiveSja;
use Treex::Core::Common;
use utf8;
use Class::Std;

use base qw(Treex::Tool::TranslationModel::Derivative::Common);

sub get_translations {
    my ( $self, $lemma, $features_array_rf ) = @_;
    my ($stem, $reflexive) = $lemma =~ /^(.+)_(s[ei])$/;
    return if !$reflexive;

    my @translations;
    foreach my $trans ($self->get_base_model->get_translations($stem)) {
        my $refl_trans = $trans->{label} . 'ся';
        push @translations, {prob=> $trans->{prob}, label=>$refl_trans, source=> 'Derivative::CS2RU::ReflexiveSja'};
    }
    return @translations;
}

1;

__END__

=encoding utf8

=head1 NAME

TranslationModel::Derivative::CS2RU::ReflexiveSja

=head1 DESCRIPTION

Backoff translation of Czech reflexive verbs (ending with "_se" or "_si") as Russian reflexives.

=head1 COPYRIGHT

Copyright 2014 Martin Popel
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
