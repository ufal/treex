package Treex::Block::T2T::EN2CS::TrLAddVariants;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2T::BaseTrLAddVariants';

use TranslationModel::Static::Model;

use TranslationModel::Derivative::EN2CS::Numbers;
use TranslationModel::Derivative::EN2CS::Hyphen_compounds;
use TranslationModel::Derivative::EN2CS::Deverbal_adjectives;
use TranslationModel::Derivative::EN2CS::Deadjectival_adverbs;
use TranslationModel::Derivative::EN2CS::Nouns_to_adjectives;
use TranslationModel::Derivative::EN2CS::Verbs_to_nouns;
use TranslationModel::Derivative::EN2CS::Prefixes;
use TranslationModel::Derivative::EN2CS::Suffixes;
use TranslationModel::Derivative::EN2CS::Transliterate;

use TranslationModel::Combined::Backoff;
use TranslationModel::Combined::Interpolated;

use Treex::Tool::Lexicon::CS;    # jen docasne, kvuli vylouceni nekonzistentnich tlemmat jako prorok#A

has '+model_dir' => ( default => 'data/models/translation/en2cs' );
has '+discr_model' => ( default => 'tlemma_czeng12.maxent.10000.100.2_1.compact.pls.gz' );
has '+static_model' => ( default => 'tlemma_czeng09.static.pls.slurp.gz' );

has human_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_humanlex.static.pls.slurp.gz',
);

override 'process_start' => sub {
    my $self = shift;

    super();

    my @interpolated_sequence = ();

    my $use_memcached = Treex::Tool::Memcached::Memcached::get_memcached_hostname();

    if ( $self->discr_weight > 0 ) {
        my $discr_model = $self->load_model( $self->_model_factory->create_model($self->discr_type), $self->discr_model, $use_memcached );
        push( @interpolated_sequence, { model => $discr_model, weight => $self->discr_weight } );
    }
    my $static_model   = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model, $use_memcached );
    my $humanlex_model = $self->load_model( TranslationModel::Static::Model->new(), $self->human_model,  0 );

    my $deverbadj_model = TranslationModel::Derivative::EN2CS::Deverbal_adjectives->new( { base_model => $static_model } );
    my $deadjadv_model = TranslationModel::Derivative::EN2CS::Deadjectival_adverbs->new( { base_model => $static_model } );
    my $noun2adj_model = TranslationModel::Derivative::EN2CS::Nouns_to_adjectives->new( { base_model => $static_model } );
    my $verb2noun_model = TranslationModel::Derivative::EN2CS::Verbs_to_nouns->new( { base_model => $static_model } );
    my $numbers_model = TranslationModel::Derivative::EN2CS::Numbers->new( { base_model => 'not needed' } );
    my $compounds_model = TranslationModel::Derivative::EN2CS::Hyphen_compounds->new( { base_model => 'not needed', noun2adj_model => $noun2adj_model } );
    my $prefixes_model = TranslationModel::Derivative::EN2CS::Prefixes->new( { base_model => $static_model } );
    my $suffixes_model = TranslationModel::Derivative::EN2CS::Suffixes->new( { base_model => 'not needed' } );
    my $translit_model = TranslationModel::Derivative::EN2CS::Transliterate->new( { base_model => 'not needed' } );
    my $static_translit = TranslationModel::Combined::Backoff->new( { models => [ $static_model, $translit_model ] } );

    # make interpolated model
    push(
        @interpolated_sequence,
        { model => $static_translit, weight => $self->static_weight },
        { model => $humanlex_model,  weight => 0.1 },
        { model => $deverbadj_model, weight => 0.1 },
        { model => $deadjadv_model,  weight => 0.1 },
        { model => $noun2adj_model,  weight => 0.1 },
        { model => $verb2noun_model, weight => 0.1 },
        { model => $numbers_model,   weight => 0.1 },
        { model => $compounds_model, weight => 0.1 },
        { model => $prefixes_model,  weight => 0.1 },
        { model => $suffixes_model,  weight => 0.1 },
    );

    #my $interpolated_model = TranslationModel::Combined::Interpolated->new( { models => \@interpolated_sequence } );
    #$combined_model = $interpolated_model;
    $self->_set_model( TranslationModel::Combined::Interpolated->new( { models => \@interpolated_sequence } ) );

    #my @backoff_sequence = ( $interpolated_model, @derivative_models );
    #my $combined_model = TranslationModel::Combined::Backoff->new( { models => \@backoff_sequence } );

    return;
};

# Require the needed models and set the absolute paths to the respective attributes
override 'get_required_share_files' => sub {
    my ($self) = @_;

    my @files = super();
    push @files, $self->model_dir ? $self->model_dir . '/' . $self->human_model : $self->human_model;
    return @files;
};

override 'process_translations' => sub {
    my ($self, @translations) = @_;
    super();
    
    # !!! hack: odstraneni nekonzistentnich hesel typu 'prorok#A', ktera se objevila
    # kvuli chybne extrakci trenovacich vektoru z CzEngu u posesivnich adjektiv,
    # lepsi bude preanalyzovat CzEng a pretrenovat slovniky

    @translations = grep {
        not($_->{label} =~ /(.+)#A/
            and Treex::Tool::Lexicon::CS::get_poss_adj($1)
            )
    } @translations;
    
    return @translations;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2CS::TrLAddVariants -- add t-lemma translation variants from translation models (en2cs translation)

=head1 DESCRIPTION

Adding t-lemma translation variants for the en2cs translation.

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
