package SEnglishA_to_SEnglishT::Mark_dsp_root;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

# vytazeno z BNC: [tag="V.*"] [word=":"] [word="\""]
# a rucne lehce profiltrovano:
my $verba_dicendi_regexp =
    'say|add|declare|comment|state|write|reply|ask|follow|read|conclude|continue|note|shout|warn|think|explain|observe|begin|assert|remark|suggest|answer|respond|argue|do|find|tell|include|announce|maintain|bellow|enquire|like|chant|remember|hear|laugh|whisper|recommend|yell|insist|stress|cry|record|proclaim|murmur|give|propose|shrugreport|mutter|entitle|claim|try|proceed|advise|go_on';

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('SEnglishT');
    my $a_root = $bundle->get_tree('SEnglishA');

    my @quote_anodes = grep { $_->get_attr('m/form') =~ /^(``|''|\")$/ } $a_root->get_descendants;

    if (@quote_anodes) {

        #      print STDERR "Quot nalezeny...\n";
        foreach my $dicendi_tnode (
            grep { $_->get_attr('t_lemma') =~ /^($verba_dicendi_regexp)$/ }
            $t_root->get_descendants
            )
        {
            my $dicendi_anode = $dicendi_tnode->get_lex_anode;
            if ($dicendi_anode) {

                #	  print STDERR "  Dicendi nalezeny...\n";
                #	  print STDERR join " ", map {$_->get_attr('m/form')} $a_root->get_descendants({ordered=>1});
                #	  print STDERR "\n";
                foreach my $tchild ( $dicendi_tnode->get_children ) {
                    my $achild = $tchild->get_lex_anode;
                    if ($achild) {

                        #	      print STDERR "  achild nalezeny...\n";
                        my ( $left_ord, $right_ord ) = sort { $a <=> $b }
                            map { $_->get_attr('ord') } ( $dicendi_anode, $achild );

                        #	      print STDERR "  interval: $left_ord - $right_ord\n";
                        if ( grep { my $ord = $_->get_attr('ord'); $left_ord < $ord and $ord < $right_ord } @quote_anodes ) {

                            #print STDERR "Nalezena prima rec, root:".$tchild->get_attr('t_lemma')."\n";;
                            $tchild->set_attr( 'is_dsp_root', 1 );
                        }
                    }
                }
            }
        }
    }
    return;
}

1;

=over

=item SEnglishA_to_SEnglishT::Mark_dsp_root

Finds direct speeches and mark their root t-nodes by setting
the C<is_dsp_root> attribute to 1.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
