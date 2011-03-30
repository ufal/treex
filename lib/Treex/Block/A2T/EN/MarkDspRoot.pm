package Treex::Block::A2T::EN::MarkDspRoot;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

# vytazeno z BNC: [tag="V.*"] [word=":"] [word="\""]
# a rucne lehce profiltrovano:
my $verba_dicendi_regexp =
    'say|add|declare|comment|state|write|reply|ask|follow|read|conclude|continue|note|shout|warn|think|explain|observe|begin|assert|remark|suggest|answer|respond|argue|do|find|tell|include|announce|maintain|bellow|enquire|like|chant|remember|hear|laugh|whisper|recommend|yell|insist|stress|cry|record|proclaim|murmur|give|propose|shrugreport|mutter|entitle|claim|try|proceed|advise|go_on';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $t_root = $zone->get_ttree;
    my $a_root = $zone->get_atree;

    my @quote_anodes = grep { $_->form =~ /^(``|''|\")$/ } $a_root->get_descendants;

    if (@quote_anodes) {

        #      print STDERR "Quot nalezeny...\n";
        foreach my $dicendi_tnode (
            grep { $_->t_lemma =~ /^($verba_dicendi_regexp)$/ }
            $t_root->get_descendants
            )
        {
            my $dicendi_anode = $dicendi_tnode->get_lex_anode;
            if ($dicendi_anode) {

                #	  print STDERR "  Dicendi nalezeny...\n";
                #	  print STDERR join " ", map {$_->form} $a_root->get_descendants({ordered=>1});
                #	  print STDERR "\n";
                foreach my $tchild ( $dicendi_tnode->get_children ) {
                    my $achild = $tchild->get_lex_anode;
                    if ($achild) {

                        #	      print STDERR "  achild nalezeny...\n";
                        my ( $left_ord, $right_ord ) = sort { $a <=> $b }
                            map { $_->ord } ( $dicendi_anode, $achild );

                        #	      print STDERR "  interval: $left_ord - $right_ord\n";
                        if ( grep { my $ord = $_->ord; $left_ord < $ord and $ord < $right_ord } @quote_anodes ) {

                            #print STDERR "Nalezena prima rec, root:".$tchild->t_lemma."\n";;
                            $tchild->set_is_dsp_root(1);
                        }
                    }
                }
            }
        }
    }
    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::MarkDspRoot

Finds direct speeches and mark their root t-nodes by setting
the C<is_dsp_root> attribute to 1.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
