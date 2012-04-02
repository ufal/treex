package Treex::Block::Misc::CopenhagenDT::ImportSentSegmFromExternalFiles;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'cdt_root_dir' => ( is => 'rw', isa => 'Str', required  => 1 );

use File::Slurp::Unicode;

sub process_bundle {
    my ( $self, $bundle ) = @_;

    if (not $bundle->get_document->file_stem =~ /(\d{4})/){
        log_warn "4-digit CDT number cannot be determined from the file name";
        return;
    }
    my $number = $1;

  ZONE:
    foreach my $zone ($bundle->get_all_zones) {

        my $language = $zone->language;
        next ZONE if $language =~ /(da|en)/;
        next ZONE if $bundle->get_document->wild->{annotation}{$language}{syntax};

        my $sent_file = $self->cdt_root_dir()."/$language/$number-$language-sentences.txt";
        if (not -f $sent_file) {
            log_warn "File with sentence boundaries not available: $sent_file";
            next ZONE;
        }

        my $a_root = $zone->get_atree;
        my @nodes = $a_root->get_descendants;

        my $sent_file_content = read_file($sent_file, encoding => 'utf8');

        my @sentences = map { _normalize($_) } split /\n/,$sent_file_content;
        my $current_sentence = shift @sentences;

        my %first_node_in_sentence;
        my $first_node_in_sentence;

        foreach my $node_index ( 0 .. $#nodes ) {
            my $node = $nodes[$node_index];
            my $word = _normalize($node->form);

            if (not defined $first_node_in_sentence) {
                $first_node_in_sentence = $node;
            }
            else {
                $first_node_in_sentence{$node} = $first_node_in_sentence;
            }

            foreach my $letter (split //,$word) {  # this should survive even different tokenizations

                if ($current_sentence eq "") {
                    $current_sentence = shift @sentences;
                    $first_node_in_sentence = undef;
                }

                elsif ( $current_sentence =~ s/^$letter// ) {
                    if ($current_sentence eq "") {
                        $current_sentence = shift @sentences;
                        $first_node_in_sentence = undef;
                    }
                }
                elsif ( $letter eq '_' ) { # hack because of wrong entities such as '&amp ;'

                }
                else {
                    log_info "Sentence from external file does not match (other type of segmentation will have to be used).\n".
                        "  Expected letter from tag: '$letter' Expected tokens from tag:  ".
                        (join ' ',map{_normalize($nodes[$_]->form)} ($node_index..$node_index+5))."\n  Unprocessed sentence tail:  $current_sentence\n";
                    next ZONE;
                }
            }
        }

        $bundle->get_document->wild->{annotation}{$language}{segmented} = 'external_file';

        foreach my $node (grep {defined $first_node_in_sentence{$_}} @nodes) {
            $node->set_parent($first_node_in_sentence{$node});
        }

    }
    return;
}

sub _normalize {
    my $string = shift;
#    log_fatal "xxx" if not defined $string;

    $string =~ s/&amp *;/\&/g;
    $string =~ s/&lt;/</g;
    $string =~ s/&gt;/>/g;
    $string =~ s/,,/"/g;
    $string =~ s/''/"/g;
#    $string =~ s/deve rivolgersi/deve cercare supporto/;
#    $string =~ s/presso/a/;
#    $string =~s/^laboratori/ailaboratori/;

    $string =~ s/ //g;
#    $string =~ s/–/-/g;

    $string =~ s/\p{IsP}/_/g;
    $string =~ s/^Vistochel/Sel/;

    return $string;
}


1;

=over

=item Treex::Block::Misc::CopenhagenDT::ImportSentSegmFromExternalFiles

If syntactic annotation is not present, then sentence boundaries based on the simple
assumption of connectivity of dependency trees cannot be used. In such cases,
sentence boundaries are based of line breaks in external *.sentences.txt files.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
