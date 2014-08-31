package Treex::Tool::Tagger::Featurama;

use strict;
use warnings;
use Moose;
use Moose::Exporter;
use Carp;
with 'Treex::Tool::Tagger::Role';

Moose::Exporter->setup_import_methods(
    as_is => ['tag_sentence'],
);

use Treex::Core::Common;
has path => (
    is            => 'ro',
    isa           => 'Str',                                  #or isa=> 'Path' ?
    predicate     => '_path_given',
    documentation => q{Path to models relative to share.},
);

has local_path => (
    is            => 'ro',
    isa           => 'Str',
    predicate     => '_local_path_given',
    documentation => q{Local path to models.},
);

has alpha => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_alpha_file',
    lazy    => 1,
);

has dict => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_dict_file',
    lazy    => 1,
);

has feature => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_feature_file',
    lazy    => 1,
);

has prune => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => q{Indicates whether we will be pruning Viterbi states},
);

has n_best => (
    is            => 'ro',
    isa           => 'Int',
    default       => 1,
    documentation => q{How many n-best results to use},
);

has order => (
    is            => 'ro',
    isa           => 'Int',
    default       => 3,
    documentation => q{Order ot the N-grams},
);

has perc => (
    is            => 'ro',
    isa           => 'Featurama::Perc',
    builder       => '_build_perc',
    lazy          => 1,
    init_arg      => undef,
    documentation => q{Wrapped C object},
);

sub _get_model_file {
    my $self   = shift;
    my $suffix = shift;
    if ( $self->_local_path_given ) {
        return $self->local_path . '.' . $suffix;
    }
    elsif ( $self->_path_given ) {
        eval {
            require Treex::Core::Resource;
            1;
        } or confess q(Treex share not available. Consider providing 'local_path' parameter);
        return Treex::Core::Resource::require_file_from_share( $self->path . '.' . $suffix );
    }
    else {
        confess q(You have to provide at least one of the 'path' and 'local_path' parameters);
    }
}

sub _build_alpha_file {
    my $self = shift;
    return $self->_get_model_file('alpha');
}

sub _build_dict_file {
    my $self = shift;
    return $self->_get_model_file('dict');
}

sub _build_feature_file {
    my $self = shift;
    return $self->_get_model_file('f');
}

sub _build_perc {
    my $self = shift;
    eval {
        require Featurama::Perc;    #when featurama will be on CPAN, it will be probably in different namespace
        1;
    } or log_fatal('Cannot load Featurama::Perc. Please check whether it is installed');
    my $perc = Featurama::Perc->new();
    my $header = join "\t", $self->_get_feature_names();

    if ( not $perc->testInit( $self->feature, $self->dict, $self->alpha, $header, $self->prune, $self->n_best, $self->order ) ) {
        log_fatal("Cannot initialize Featurama::Perc");
    }
    return $perc;
}

sub DEMOLISH {
    my $self = shift;

    # We must prevent lazy building of $self->perc during DEMOLISH
    # because in that case "require Featurama::Perc" fails (we are in cleanup).
    # Therefore, we cannot use $self->perc in the condition below.
    if ( $self->{perc} ) {
        $self->perc->testFinish();
    }
}

sub tag_sentence {
    my ( $self, $wordforms_rf, $analyses_rf ) = @_;

    if ( !$analyses_rf ) {

        # array of analyses, each analysis is an array of lemma/tag info stored in a hash
        my @temp = @{$wordforms_rf};
        my @analyses = map { [ $self->_analyze($_) ] } @temp;

        $analyses_rf = \@analyses;
    }

    # tagging
    return $self->_tag( $wordforms_rf, $analyses_rf );
}

sub _get_feature_names {
    log_fatal( 'This method has to be overriden: ' . ( caller(0) )[3] );
}

sub _get_features {
    log_fatal( 'This method has to be overriden: ' . ( caller(0) )[3] );
}

sub _extract_tag_and_lemma {
    log_fatal( 'This method has to be overriden: ' . ( caller(0) )[3] );
}

sub _analyze {
    log_fatal( 'This method has to be overriden: ' . ( caller(0) )[3] );
}

sub _tag {
    my ( $self, $forms, $analyses ) = @_;

    my @sent;

    # extract features
    foreach my $i ( 0 .. $#{$forms} ) {    #go through word forms and analyses

        my @word = $self->_get_features( $forms, $analyses, $i );    #load features
        push( @sent, \@word );
    }

    $self->perc->beginSentence();
    foreach my $word_rf (@sent) {
        $self->perc->appendWord( join( "\t", @{$word_rf} ) );
    }
    $self->perc->endSentence();

    my ( @tags, @lemmas );
    foreach my $i ( 0 .. $#{$forms} ) {
        my $tag_and_lemma = $self->_extract_tag_and_lemma( $i, $forms->[$i] );
        push( @tags,   $tag_and_lemma->{tag} );
        push( @lemmas, $tag_and_lemma->{lemma} );
    }

    return ( \@tags, \@lemmas );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Tagger::Featurama - base class for Featurama PoS taggers

=head1 DESCRIPTION

Perl wrapper for Featurama implementation of Collins' perceptron algorithm.
This class cannot be instantiated directly,
you must use derived classes which override methods C<_get_features()>,
C<_get_feature_names()> and probably also C<_analyze>.

=head1 SYNOPSIS

 use Treex::Tool::Tagger::Featurama::SomeDerivedClass;

 my @wordforms = qw(John loves Jack);

 my $tagger = Treex::Tool::Tagger::Featurama::SomeDerivedClass->new(path => '/path/to/model');

 my ($tags_rf, $lemmas_rf) = $tagger->tag_sentence(\@wordforms);

=head2 CONSTRUCTOR

=over

=item  my $tagger = Treex::Tool::Tagger::Featurama->new(path = '/path/to/model');

=back

=head2 METHODS

=over

=item  my ($tags_rf) = $tagger->tag_sentence(\@wordforms);

=back

=head2 METHODS TO OVERRIDE

=over

=item _analyze($wordform)

This method should provide all possible morphological analyses for the given wordform.

=item _get_feature_names()

This method should return an array of feature names.

=item _get_features($wordforms_rf, $analyses_rf_rf, $index)

This method should return an array of features, given 
all wordforms in the sentence,
all possible morphological analyses for each of the wordforms,
and a position in the sentence.
Since the features may include parts of the context, it is necessary to provide the whole
sentence to this function.
For example:

 $featurama->_get_features(
     [qw(Time flies)],
     [[qw(NN NNP VB JJ)], [qw(VBZ NNS)]],
     0
 );

=item _extract_tag_and_lemma($index, $wordform)

This method should extract tag and lemma given index in sentence and wordform.
It will probably want to use $self->perc
TODO this will probably change

=back

=head1 SEE ALSO

L<Treex::Tool::Tagger::Featurama::EN>
L<Treex::Tool::Tagger::Featurama::CS>

=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

