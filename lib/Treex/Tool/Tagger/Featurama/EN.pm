package Treex::Tool::Tagger::Featurama::EN;

use strict;
use warnings;
use Moose;
extends 'Treex::Tool::Tagger::Featurama';

use Treex::Tool::EnglishMorpho::Analysis;

has _analyzer => (
    is       => 'ro',
    isa      => 'Treex::Tool::EnglishMorpho::Analysis',
    builder  => '_build_analyzer',
    lazy     => 1,
    init_arg => undef,
);

sub BUILDARGS {
    return { path => 'data/models/tagger/featurama/en/default' };
}

sub _build_analyzer {
    my $self = shift;
    return Treex::Tool::EnglishMorpho::Analysis->new();
}

override '_analyze' => sub {
    my ( $self, $wordform ) = @_;

    return map {
        {
            tag   => $_,
            lemma => $wordform,
        }
    } ( $self->_analyzer->get_possible_tags($wordform) );
};

override '_get_feature_names' => sub {
    return qw(Form Prefix1 Prefix2 Prefix3 Prefix4 Prefix5 Prefix6 Prefix7 Prefix8 Prefix9 Suffix1 Suffix2
        Suffix3 Suffix4 Suffix5 Suffix6 Suffix7 Suffix8 Suffix9 Num Cap Dash Tag);
};

override '_get_features' => sub {
    
    my ( $self, $forms, $analyses, $i ) = @_;
    my $wordform = $forms->[$i];
    my $analysis = $analyses->[$i];

    my @features;

    #Form
    push( @features, $wordform );

    #Prefixes
    push( @features, substr( $wordform, 0, 1 ) );
    push( @features, substr( $wordform, 0, 2 ) );
    push( @features, substr( $wordform, 0, 3 ) );
    push( @features, substr( $wordform, 0, 4 ) );
    push( @features, substr( $wordform, 0, 5 ) );
    push( @features, substr( $wordform, 0, 6 ) );
    push( @features, substr( $wordform, 0, 7 ) );
    push( @features, substr( $wordform, 0, 8 ) );
    push( @features, substr( $wordform, 0, 9 ) );

    #Suffixes
    push( @features, substr( $wordform, -1, 1 ) );
    push( @features, substr( $wordform, -2, 2 ) );
    push( @features, substr( $wordform, -3, 3 ) );
    push( @features, substr( $wordform, -4, 4 ) );
    push( @features, substr( $wordform, -5, 5 ) );
    push( @features, substr( $wordform, -6, 6 ) );
    push( @features, substr( $wordform, -7, 7 ) );
    push( @features, substr( $wordform, -8, 8 ) );
    push( @features, substr( $wordform, -9, 9 ) );

    #Num
    push( @features, $wordform =~ /[0-9]/ ? 1 : 0 );

    #Cap
    push( @features, $wordform =~ /[[:upper:]]/ ? 1 : 0 );

    #Dash
    push( @features, $wordform =~ /-/ ? 1 : 0 );

    # Tag
    push( @features, "NULL" );

    # Analyses
    push @features, map { $_->{'tag'} } @{$analysis};
    return @features;
};

override '_extract_tag_and_lemma' => sub {
    my ( $self, $index, $wordform ) = @_;
    return {
        tag => $self->perc->getProposedTag( $index, 0 ),
        lemma => $wordform,
    };
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Tagger::Featurama::EN

=head1 DESCRIPTION

Featurama feature set and analysis for English

=head2 OVERRIDEN METHODS

=over

=item _analyze($wordform)

Uses EnglishMorpho::Analysis::get_possible_tags()

=item _get_feature_names()

Returns feature names for English

=item _get_features($wordform, $analyses_rf)

Returns features for English

=item _extract_tag_and_lemma($index, $wordform)

Returns proposed tag and wordform

=back

=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


