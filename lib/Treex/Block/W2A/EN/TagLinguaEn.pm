package Treex::Block::W2A::EN::TagLinguaEn;
use 5.010;
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
    predicate     => '_tagger_built',
    documentation => q{Tagger object},
);

has _form_corrections => (
    is => 'ro',
    isa => 'HashRef[Str]',
    default => sub { {
            q(``)=>q("),
            q('')=>q("),
        }},
    documentation => q{Possible changes in forms done by tagger},
);

sub _build_tagger {
    my $self   = shift;
    my $tagger = Lingua::EN::Tagger->new();
    return $tagger;
}

sub _revert_form { #because Lingua::EN::Tagger changes some forms to another, we need to restore original
    my $self = shift;
    my %args = @_;
    my $new = $args{new};
    return $self->_form_corrections->{$new} // $new;
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
    log_fatal(qq{There's already atree in zone}) if $zone->has_atree();
    log_debug("Processing sentence: $sentence");

    #split on whitespace, tags nor tokens doesn't contain spaces
    my @tagged = split /\s+/, $self->_tagger->add_tags($sentence);

    # create a-tree
    my $a_root    = $zone->create_atree();
    my $tag_regex = qr{
        <(\w+)> #<tag>
        ([^<]+) #form
        </\1>   #</tag>
        }x;
    my $space_start = qr{^\s+};
    my $ord         = 1;
    foreach my $tag_pair (@tagged) {
        if ( $tag_pair =~ $tag_regex ) {
            my $form = $self->_revert_form( new => $2 );
            my $tag = $self->_correct_lingua_tag( $1, $form );
            if ( $sentence =~ s/^\Q$form\E// ) {

                #check if there is space after word
                my $no_space_after = $sentence =~ m/$space_start/ ? 0 : 1;
                if ( $sentence eq q{} ) {
                    $no_space_after = 0;
                }

                #delete it
                $sentence =~ s{$space_start}{};

                # and create node under root
                my $new_a_node = $a_root->create_child(
                    form           => $form,
                    tag            => $tag,
                    no_space_after => $no_space_after,
                    ord            => $ord++,
                );
            }
            else {
                log_fatal("Mismatch between tagged word and original sentence: Tagged: $form. Original: $sentence.");
            }
        }
        else {
            log_fatal("Incorrect output format from Lingua::EN::Tagger: $tag_pair");
        }

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


