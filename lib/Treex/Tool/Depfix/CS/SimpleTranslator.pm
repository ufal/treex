package Treex::Tool::Depfix::CS::SimpleTranslator;
use Moose;
use Treex::Core::Common;
use utf8;

use Treex::Tool::TranslationModel::Static::Model;
use Treex::Core::Resource;
use Data::Dumper;

my $model = undef;
my $model_file = "data/models/translation/en2cs/tlemma_czeng09.static.pls.slurp.gz";

sub BUILD {
    my ($self) = @_;

    if (!defined $model) {
        $model = Treex::Tool::TranslationModel::Static::Model->new();
        $model->load(
            Treex::Core::Resource::require_file_from_share($model_file));
    }

    return ;
}

sub translate_lemma {
    my ($self, $lemma) = @_;

    my ($best) = $model->get_translations( lc($lemma) );
    my $translation = $best->{label};
    if (defined $translation && $translation =~ /^([^#]+)#(.+)$/) {
        my $tr_lemma = $1;
        my $tag = $2;
        log_info "SimpleTranslator: $lemma -> $tr_lemma";
        return ($tr_lemma, $tag);
    }
    else {
        log_info "SimpleTranslator: Cannot translate $lemma!";
        return $lemma;
    }
}


=head1 NAME 

Treex::Tool::Depfix::CS::SimpleTranslator

=head1 DESCRIPTION


=head1 METHODS

=over

=item

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
