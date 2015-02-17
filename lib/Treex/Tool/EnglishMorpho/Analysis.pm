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

sub BUILD {
    my ($self) = @_;
    
    # Force the lazy-built parameters to be loaded.
    # This should not be needed, but for some strange reasons it is.
    # Without this Morce::English tags "But" as IN instead of CC.
    # echo "But" | treex -Len -t W2A::EN::TagMorce Write::CoNLLX
    # There is some black magic behind, because in both cases
    # (with this pre-loading and without),
    # get_possible_tags('But') returns the same list of possible tags.
    $self->my_dict;
    $self->big_dict;
    $self->preterites;
    $self->participles;
    return;
}

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
    my @possible;

    # 1. check my_dict for closed-class words. If yes, this is the last step.
    my $dict_tags = $self->my_dict->{$lowerform};
    if ($dict_tags){
        @possible = keys %{$dict_tags};
        if ( $lowerform ne $wordform ) {
            push @possible, qw(NNP);
        }
        return @possible;
    }
    
    # 2a. check big_dict
    $dict_tags = $self->big_dict->{$lowerform};
    if ($dict_tags){
        @possible = keys %{$dict_tags};
        if ( $lowerform ne $wordform ) {
            push @possible, qw(NNP NNPS);
        }
    } 
    
    # 2b apply morpho guesses, recall is more important than precision
    else {
        push @possible, qw(FW JJ NN NNS RB);

        # comparative
        if ($lowerform =~ /er($|-)|^more-|^less-/) {
            push @possible, qw(JJR RBR);
        }    
        
        # superlative
        if ($lowerform =~ /est($|-)|^most-|^least/) {
            push @possible, qw(JJS RBS);
        }    
        
        # -ing form
        if ( $lowerform =~ /ing$|[^aeiouy]in$/ ) {
            push @possible, qw(VBG);
        }
        
        # third person
        if ( $lowerform =~ /[^s]s$/ ) {
            push @possible, qw(VBZ);
        }
        else {
            push @possible, qw(VB VBP);
        }
        
        # capital-letter (proper nouns and adjactives)
        if ( $lowerform ne $wordform ) {
            push @possible, qw(NNP NNPS);
        }    
        elsif ( $lowerform =~ /^[0-9']/ ) {
            push @possible, qw(NNP);
        }
        
        #  symbols
        if ($lowerform =~ /[^a-zA-Z0-9]+/ or $lowerform =~ /^&.*;$/ )
        {
            push @possible, qw(SYM);
#            if ($lowerform =~ /^[^a-zA-Z0-9]+$/){ # variant: make only symbols possible
#                @possible = ('SYM', ':', ',');
#            }
        }
        
        # numbers
        if ( $lowerform =~ /[-0-9]+/ or $lowerform =~ /^[ixvcmd\.]+$/ ) {
            push @possible, qw(CD);
        }
    }
    
    # 3. check irregular verbs
    if ( $self->preterites->{$lowerform} ) {
        push @possible, qw(VBD);
    }
    if ( $self->participles->{$lowerform} ) {
        push @possible, qw(VBN);
    }
    if ( $lowerform =~ /ed$/ ) {
        push @possible, qw(VBD VBN);
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


