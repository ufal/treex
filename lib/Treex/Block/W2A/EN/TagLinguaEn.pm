package Treex::Block::W2A::EN::TagLinguaEn;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Lingua::EN::Tagger;
has _tagger => (
    is            => 'ro',
    isa           => 'Lingua::EN::Tagger',
    builder       => '_build_tagger',
    lazy          => 1,
    init_arg      => undef,
    predicate     => '_tagger_builded',
    documentation => q{Tagger object},
);

sub _build_tagger {
    my $self   = shift;
    my $tagger = Lingua::EN::Tagger->new();
    return $tagger;
}

sub _correct_lingua_tag {    # substitution according to http://search.cpan.org/src/ACOBURN/Lingua-EN-Tagger-0.13/README
                             # puvodni tagset je na http://www.computing.dcu.ie/~acahill/tagset.html
    my ( $self, $linguatag, $wordform ) = @_;

    if ( $linguatag eq "DET" ) {
        return "DT";
    }
    elsif ( $linguatag eq "PRPS" ) {
        return "PRP\$";
    }
    elsif ( $linguatag =~ /^[LR]RB$/ ) {
        return "-$linguatag-";
    }
    elsif ( $linguatag =~ /^PP/ ) {    # allowed "tags" of punctuation mark in PennTB: #  $ '' ( ) , . : ``
        if ( $wordform =~ /^(#|$|''|,|\.|:|``)$/ ) {
            return $wordform
        }
        elsif ( $wordform =~ /[\(\[\{]/ ) {
            return "-LRB-"
        }
        elsif ( $wordform =~ /[\)\]\}]/ ) {
            return "-RRB-"
        }
        else {
            return ".";
        }

    }    # v lingua-taggeru maji pro punktuaci zvlastni tagy, to ale v ptb nebylo!

    #  elsif ($linguatag eq "LRB") {return "."}  # hack, zavorky totiz collins nesezere  - tyhle vsechny zameny by spis mely bejt ve wrapperu ke collinsu
    #  elsif ($linguatag eq "RRB") {return "."}
    #  elsif ($linguatag eq "PP") {return "."}
    #  elsif ($linguatag eq "PPL") {return "``"}
    #  elsif ($linguatag eq "PPR") {return "''"}
    #  elsif ($linguatag eq "PPC") {return ","}
    #  elsif ($linguatag eq "PPS") {return ","}    #POZOR, cunarna, tagger dava PPS pomlcce a Collins na tom pak pada, ale nevim, jaky tag teda patri

    else {
        return $linguatag;
    }
}
}

sub process_atree {
    my ( $self, $atree ) = @_;
    my @descendants = $atree->get_descendants();
    my @forms = map { $_->form } @descendants;

    # get tags
    my $joined = join ' ', @forms;
    my $tagged = $self->_tagger->add_tags($joined);
    my @pairs   = split m{\s}, $tagged;
    if ( scalar @tags != scalar @forms ) {
        log_fatal("Different number of tokens and tags. TOKENS: @forms, TAGS: @tags");
    }

    # fill tags
    foreach my $a_node (@descendants) {
        my $pair = shift @tags;
        if (m{(.+)/(.+)}gx) {
            my $wordform = $1;
            my $tag = $self->_correct_lingua_tag($2, $wordform);
            my $original = $a_node->form;
            log_fatal("Mismatched tokenization: expected: $form, got: $wordform") if $wordform ne $original;
            $a_node->set_tag( $tag );
        } else log_fatal("Bad format of tagged data: $pair");
    }

    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::TagLinguaEn

=head1 VERSION

=head1 DESCRIPTION

Each node in analytical tree is tagged using C<Lingua::EN::Tagger> (Penn Treebank POS tags).
Because Lingua::EN::Tagger does its own tokenization, it checks if tokenization is same.

=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


