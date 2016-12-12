package Treex::Block::Coref::Load::SemEval2010;
use Moose;
use Treex::Core::Common;
use Data::Printer;
use List::MoreUtils qw/uniq/;
use Treex::Block::W2A::EN::Tokenize;
use Treex::Block::W2A::RU::Tokenize;
use Treex::Block::W2A::DE::Tokenize;

extends 'Treex::Core::Block';

has 'from_pattern' => ( 
    is => 'ro', 
    isa => 'Str', 
    required => 1, 
    documentation => 'A pattern of the path to search for the file to be loaded. The placeholder <BASE> is substituted with 
        the actual input file\'s basename (without its extension)',
); 

sub _build_annotation {
    my ($self, $doc) = @_;

    my $from = $self->from_pattern;
    my $base = $doc->file_stem;
    $from =~ s/<BASE>/$base/g;

    my @annotation = ();
    my @curr_sent;

    my $lang = $self->language;
    my $tokenizer = ($lang eq "en") ? Treex::Block::W2A::EN::Tokenize->new() :
        ($lang eq "ru") ? Treex::Block::W2A::RU::Tokenize->new() :
        ($lang eq "de") ? Treex::Block::W2A::DE::Tokenize->new() : undef;

    open my $from_fh, "<:utf8", $from;
    while (<$from_fh>) {
        chomp $_;
        next if ($_ =~ /^\#/);
        if ($_ =~ /^\s*$/) {
            next if (!@curr_sent);
            push @annotation, [ @curr_sent ];
            @curr_sent = ();
        }
        else {
            my @cols = split /\t/, $_;
            # store only the form (col 3) and the coref info (col 11)
            if (defined $tokenizer) {
                my $wordstr = $cols[3];
                $wordstr =~ s/-LRB-/(/g;
                $wordstr =~ s/-RRB-/)/g;
                $wordstr =~ s/''/``/g;
                $wordstr = $tokenizer->tokenize_sentence($wordstr);
                my @words = split /\s/, $wordstr;
                foreach my $w (@words) {
                    push @curr_sent, [$w, $cols[11]];
                }
            }
            else {
                push @curr_sent, [$cols[3], $cols[11]];
            }
        }
    }

    return @annotation;
}

sub process_document {
    my ($self, $doc) = @_;
    my @annot = $self->_build_annotation($doc);

    my @atrees = map {$_->get_tree($self->language, 'a', $self->selector)} $doc->get_bundles;
    foreach my $atree (@atrees) {
        my @annot_sent = @{ shift @annot };

        _process_sentence($atree, @annot_sent);
        
    }
}


sub _process_sentence {
    my ($atree, @conll_sent) = @_;

    my @anodes = $atree->get_descendants({ordered => 1});
    
    my $j = 0;
    for (my $i = 0; $i < @anodes; $i++) {
        my $eq = 0;

        my $w_size = 10;
        my ($iws, $jws) = ($i, $j);
        my $iwe = $i + $w_size;
        my $jwe = $j + $w_size;
        while ($i < @anodes && $i < $iwe) {
            $j = $jws;
            while ($j < @conll_sent && $j < $jwe) {
                #printf STDERR "%s %s\n", $anodes[$i]->form, $conll_sent[$j]->[0];
                $eq = ($anodes[$i]->form eq $conll_sent[$j]->[0]);
                last if ($eq);
                $j++;
            }
            last if ($eq);
            $i++;
        }
        if ($eq || ($i == @anodes && $j == @conll_sent)) {
            if ($j > $jws || $i > $iws) {
                #printf STDERR "%d-%d -> %d-%d\n", $jws, $j-1, $iws, $i-1;
                #printf STDERR "CONLL: %s\n", join(" ", map {$_->[0]} @conll_sent[$jws .. $j-1]);
                #printf STDERR "ANODES: %s\n", join(" ", map {$_->form} @anodes[$iws .. $i-1]);
            }
            my @coref_info = uniq grep {$_ ne '-'} map {$_->[1]} @conll_sent[$jws .. $j-1];
            my $coref_info_str = join "|", @coref_info;
            for (my $k = $iws; $k < $i; $k++) {
                log_warn "Multiple coreference information stored to anode ".$anodes[$k]->id.": ".$coref_info_str if (@coref_info > 1);
                set_coref_mention_wilds($anodes[$k], $coref_info_str);
            }
            if ($i < @anodes && $j < @conll_sent) {
                set_coref_mention_wilds($anodes[$i], $conll_sent[$j]->[1]);
            }
        }
        else {
            log_fatal "Too different.";
        }
        $j++;
    }
}

sub set_coref_mention_wilds {
    my ($anode, $coref_info_str) = @_;
    my @coref_info = split /\|/, $coref_info_str;
    my @entity_start_idxs = map {$_ =~ /\((\d+)/; $1} grep {$_ =~ /\(\d+/} @coref_info;
    my @entity_end_idxs = map {$_ =~ /(\d+)\)/; $1} grep {$_ =~ /\d+\)/} @coref_info;
    $anode->wild->{coref_mention_start} = [ @entity_start_idxs ] if (@entity_start_idxs);
    $anode->wild->{coref_mention_end} = [ @entity_end_idxs ] if (@entity_end_idxs);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Coref::Load::SemEval2010

=head1 DESCRIPTION

A block to import coreference annotated in SemEval2010 (CoNLL) style.
Several not very transparent adjustments must have been done to align
the tokenization within the a-trees and tokenization in the CoNLL files.


=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
