package Treex::Tool::EnglishMorpho::Analysis;

use strict;
use warnings;
use Moose;

use Treex::Core::Log;
use Treex::Core::Resource qw(require_file_from_share);

my @params = qw(my_dict big_dict preterites participles);
foreach my $param (@params) {
    has $param => (
        is       => 'ro',
        isa      => 'HashRef',
        lazy     => 1,
        builder  => "_build_$param",
        init_arg => undef,
    );
}

has 'data_dir' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'data/models/morpho_analysis/en',
);

# --------- initialization ---------

sub _build_my_dict {
    my $self = shift;
    return $self->_load_dictionary( require_file_from_share( $self->data_dir . '/muj_slovnik.txt' ) );
}

sub _build_big_dict {
    my $self = shift;
    return $self->_load_dictionary( require_file_from_share( $self->data_dir . '/big_slovnik.txt' ) );
}

sub _build_preterites {
    my $self = shift;
    return $self->_load_list( require_file_from_share( $self->data_dir . '/preterite.tsv' ) );
}

sub _build_participles {
    my $self = shift;
    return $self->_load_list( require_file_from_share( $self->data_dir . '/participle.tsv' ) );
}

sub _load_dictionary {
    my $self = shift;
    my $file = shift;
    my $dict;
    open my $DATA, '<', $file or treex_fatal("Can't open morphology file $file.");
    LOAD:
    while (<$DATA>) {
        chomp;
        next LOAD if $_ eq q{};
        my @items = split qr/ /, $_;
        my $word = lc shift(@items);
        foreach my $tag (@items) {
            $dict->{$word}->{$tag} = 1;
        }
    }
    close($DATA);
    return $dict;
}

sub _load_list {
    my $self = shift;
    my $file = shift;
    my $list;
    open my $DATA, '<', $file or treex_fatal("Can't open morphology file $file.");
    while (<$DATA>) {
        chomp;
        $list->{$_} = 1;
    }
    close($DATA);
    return $list;
}

# --------- interface ---------

sub get_possible_tags {    ## no critic (Subroutines::ProhibitExcessComplexity) this is complex
    my $self      = shift;
    my $wordform  = shift;
    my $lowerform = lc($wordform);

    my %muj_slovnik    = %{ $self->my_dict };
    my %big_slovnik    = %{ $self->big_dict };
    my %past_slovesa   = %{ $self->preterites };
    my %partic_slovesa = %{ $self->participles };

    my @possible;

    if ( exists $muj_slovnik{$lowerform} ) {
        foreach my $tag ( keys %{ $muj_slovnik{$lowerform} } ) {
            push @possible, $tag;
        }
        if ( $lowerform ne $wordform ) {
            push @possible, qw(NNP);
        }
    }
    else {    # neni ve slovniku uzavrenych trid
        if ( exists $big_slovnik{$lowerform} ) {
            foreach my $tag ( keys %{ $big_slovnik{$lowerform} } ) {
                push @possible, $tag;
            }
            if ( $lowerform ne $wordform ) {
                push @possible, qw(NNP NNPS);
            }
        }
        else {
            push @possible, qw(FW JJ NN NNS RB);

            if (( $lowerform =~ /er$/ )
                or ( $lowerform =~ /er-/ )
                or
                ( $lowerform =~ /more-/ ) or ( $lowerform =~ /less-/ )
                )
            {
                push @possible, qw(JJR RBR);

            }    # comparative
            if (( $lowerform =~ /est$/ )
                or ( $lowerform =~ /est-/ )
                or
                ( $lowerform =~ /most-/ ) or ( $lowerform =~ /least-/ )
                )
            {
                push @possible, qw(JJS RBS);
            }    # superlative
            if ( ( $lowerform =~ /ing$/ ) or ( $lowerform =~ /[^aeiouy]in$/ ) ) {
                push @possible, qw(VBG);
            }
            if ( $lowerform =~ /[^s]s$/ ) {
                push @possible, qw(VBZ);
            }    # 3. os
            else {
                push @possible, qw(VB VBP);
            }    # non-3. os

            if ( $lowerform ne $wordform ) {
                push @possible, qw(NNP NNPS);
            }
            elsif ( $lowerform =~ /^[0-9']/ ) {
                push @possible, qw(NNP);
            }
            if (( $lowerform =~ /[^a-zA-Z0-9]+/ )
                or
                ( $lowerform =~ /^&.*;$/ )
                )
            {
                push @possible, qw(SYM);
            }
            if ( ( $lowerform =~ /[-0-9]+/ ) or ( $lowerform =~ /^[ixvcmd\.]+$/ ) ) {
                push @possible, qw(CD);
            }
        }
        if ( exists $past_slovesa{$lowerform} ) {
            push @possible, qw(VBD);
        }
        if ( exists $partic_slovesa{$lowerform} ) {
            push @possible, qw(VBN);
        }
        if ( $lowerform =~ /ed$/ ) {
            push @possible, qw(VBD VBN);
        }
    }
    return @possible;
}

1;

=head1 NAME

Treex::Tool::EnglishMorpho::Analysis - rule based morphological analyzer for English


=head1 SYNOPSIS

 use Treex::Tool::EnglishMorpho::Analysis;

 my $analyser = Treex::Tool::EnglishMorpho::Analysis->new();
 foreach my $wordform (qw(John loves the yellow ball of his sister .)) {
   my @tags = $analyser->get_possible_tags($wordform);
   print "$wordform -> @tags\n";
 }



=head1 DESCRIPTION

Method get_possible_tags($wordform) returns the list of PennTreebank-style
morphological tags for the given word form.

=head1 METHODS

=over 4

=item get_possible_tags

Given wordform returns list of possible POS tags.

=back

=head1 AUTHORS

Johanka Drahomíra Doležalová

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


