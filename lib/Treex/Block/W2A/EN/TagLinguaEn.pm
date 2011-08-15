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

sub process_zone {
    my ( $self, $zone ) = @_;

    # get the source sentence
    my $sentence = $zone->sentence;

    log_fatal("No sentence in zone") if !defined $sentence;

    #split on whitespace, tags nor tokens doesn't contain spaces
    my @tagged = split /\s+/, $self->_tagger->add_tags($sentence);

    # create a-tree
    my $a_root      = $zone->create_atree();
    my $tag_regex   = qr{
        <(\w+)> #<tag>
        ([^<]+) #form
        </\1>   #</tag>
        }x;
    my $space_start = qr{^\s+};
    my $ord         = 1;
    foreach my $tag (@tagged) {
        if ( $tag =~ $tag_regex ) {
            my $form = $2;
            my $tag = $self->_correct_lingua_tag( $1, $form );
            if ( $sentence =~ s/^\Q$form\E// ) {

                #check if there is space after word
                my $no_space_after = $sentence =~ m/$space_start/ ? 0 : 1;
                if ($sentence eq q{}) {
                    $no_space_after = 0;
                }
                #delete it
                $sentence =~ s{$space_start}{};

                # and create node under root
                my $new_a_node = $a_root->create_child(
                    form           => $form,
                    no_space_after => $no_space_after,
                    ord            => $ord++,
                );
            }
            else {
                log_fatal("Mismatch between tagged word and original sentence: Tagged: $form. Original: $sentence.");
            }
        }
        else {
            log_fatal("Incorrect output format from Lingua::EN::Tagger: $tag");
        }

    }
    return 1;
}

#sub process_atree {
#    my ( $self, $atree ) = @_;
#    my @descendants = $atree->get_descendants();
#    my @forms = map { $_->form } @descendants;
#
#    # get tags
#    my $joined = join ' ', @forms;
#    my $tagged = $self->_tagger->add_tags($joined);
#    my @pairs  = split m{\s}, $tagged;
#    if ( scalar @pairs != scalar @forms ) {
#        log_fatal("Different number of words and tags. Words: @forms, TAGS: @pairs");
#    }
#
#    # fill tags
#    foreach my $a_node (@descendants) {
#        my $pair = shift @pairs;
#        if (m{(.+)/(.+)}gx) {
#            my $wordform = $1;
#            my $tag      = $self->_correct_lingua_tag( $2, $wordform );
#            my $original = $a_node->form;
#            log_fatal("Mismatched tokenization: expected: $original, got: $wordform") if $wordform ne $original;
#            $a_node->set_tag($tag);
#        }
#        else {
#            log_fatal("Bad format of tagged data: $pair");
#        }
#    }
#
#    return 1;
#}

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


