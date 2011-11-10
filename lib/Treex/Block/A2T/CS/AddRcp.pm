package Treex::Block::A2T::CS::AddRcp;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $rcp_verb_list_pl = 'podobat_se|lišit_se|odlišovat_se';
my $rcp_verb_list_without_s = 'dohadovat_se|hádat_se|potkat_se|prát_se|přetahovat_se|sdružit_se|sdružovat_se|vyříkat_si|dohodnout|dohodnout_se|shodnout_se|sejít_se|scházet_se|srazit_se|střetávat_se|střetnout_se|rozcházet_se|utkat_se|utkávat_se|setkat_se|setkávat_se|domlouvat_se|domluvit_se|povídat_si|vystřídat_se|shodovat_se|střídat_se|sloučit_se|sjednotit_se|seznámit_se|vyměnit_si';
my $rcp_verb_list_has_se = 'potkat';
my $rcp_verb_list_mezi_pat = 'rozlišit|rozlišovat';
my $rcp_verb_list_pl_pat = 'sjednocovat|sjednotit|sdružovat|sdružit|porovnávat';
my $rcp_verb_list_has_spolu = 'bavit_se|mluvit|hovořit|diskutovat';
my $rcp_jine = 'jednat|projednat|projednávat|dojednat|sjednat';
# my $rcp_jine2 = 'setkat_se|setkávat_se|domlouvat_se|domluvit_se|povídat_si'; # podminka: mnozne cislo + s nekym anim + oba museji byt vedle sebe
my $rcp_jine3 = 'bavit_se';

my $rcp_lemmas_path = "/a/gah/tmp/tectomt/personal/linh/pdt_to_tmt/rcp/data/rcp_verb_lemma_functor.txt";
my $ewn_path = "/a/gah/tmp/tectomt/personal/linh/common/noun_to_ewn_top_ontology.tsv";

my %rcp_lemma_cnt;
my @group_lemmas;

sub get_rcp_verb_lemma_functor {
    my ($path) = @_;
    my %rcp_lemma;
    open(RCP, "<:encoding(UTF-8)", $path) || die "Can't open $path: $!";
    my ($prev_cnt, $prev_lemma, $prev_functor) = ("", "", "");
    while ( my $line = <RCP> ) {
        chomp $line;
        $line =~ s/^\s+//;
        my ($cnt, $lemma, $functor) = split "\ ", $line;
        if ( $prev_lemma eq $lemma ) {
            $rcp_lemma{$lemma}{"cnt"} += $cnt;
            $rcp_lemma{$lemma}{"functor"} = $functor if ( $prev_cnt < $cnt );
        }
        else {
            $rcp_lemma{$lemma}{"cnt"} = $cnt;
            $rcp_lemma{$lemma}{"functor"} = $functor;
        }
        ($prev_cnt, $prev_lemma, $prev_functor) = ($cnt, $lemma, $functor);
    }
    close(RCP);
    return %rcp_lemma;
}

sub get_ewn_group_lemmas {
    my ($path) = @_;
    my @group_lemmas;
    open(EWN, "<:encoding(UTF-8)", $path) || die "Can't open $path: $!";
    while ( my $line = <EWN> ) {
        chomp $line;
        my ($lemma, $class_list) = split "\t", $line;
        $class_list =~ s/^\s+//g;
        $class_list =~ s/\s+$//g;
        my @classes = split "\ \ \ \ ", $class_list;
        foreach my $class ( @classes ) {
            if ( $class =~ /Group\ Human/ ) {
                push @group_lemmas, $lemma;
                last;
            }
        }
    }
    close(EWN);
    return @group_lemmas;
}


sub BUILD {
    %rcp_lemma_cnt = get_rcp_verb_lemma_functor($rcp_lemmas_path);
    @group_lemmas = get_ewn_group_lemmas($ewn_path);
}

# spolupracovali s nekym -> no Rcp!
sub has_S {
    my ($t_node) = @_;
    foreach my $echild ( $t_node->get_echildren( { or_topological => 1 } ) ) {
        if ( grep { $_->lemma =~ /^s([-_].*)?$/ } $echild->get_anodes ) {
            return 1;
        }
    }
    return 0;
}

sub has_SE {
    my ($t_node) = @_;
    foreach my $echild ( $t_node->get_echildren( { or_topological => 1 } ) ) {
        if ( grep { $_->lemma =~ /^se([-_].*)?$/ } $echild->get_anodes ) {
            return 1;
        }
    }
    return 0;
}

# ### typ MEZI
sub has_MEZI {
    my ($t_node) = @_;
    foreach my $echild ( $t_node->get_echildren( { or_topological => 1 } ) ) {
        if ( ($echild->functor || "") eq "PAT" 
            and ($echild->get_attr('gram/sempos') || "") =~ /^n/ 
            and grep { $_->form eq "mezi" } $echild->get_anodes ) {
            return 1;
        }
    }
    return 0;
}

# ### typ VZAJEMNE
sub has_VZAJEMNE {
    my ($t_node) = @_;
    return ( grep { $_->t_lemma =~ /^(vzájemný|navzájem)$/ } $t_node->get_echildren( { or_topological => 1 } ) ) ? 1 : 0;
}

# ### typ SPOLU
sub has_SPOLU {
    my ($t_node) = @_;
    return ( grep { $_->t_lemma eq "společný" } $t_node->get_echildren( { or_topological => 1 } ) ) ? 1 : 0;
}

sub is_subject {
    my ($t_node) = @_;
    return 1 if ( $t_node->get_lex_anode and $t_node->get_lex_anode->afun eq "Sb" );
    return (
        grep {
            $_->functor eq "RSTR"
            and ($_->get_attr('gram/sempos') || "") =~ /^adj\.quant/
            and $_->get_lex_anode
            and $_->get_lex_anode->afun eq "Sb"
        } $t_node->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

# # # returns 1 if node is
# 1. plural (predstavitele)
# 2. human group (parlament)
# 3. in conjuction (Jan a Marie, Sparta - Slavie)
# 4. quantitative (rada lidi)
sub is_pl {
    my ($t_node) = @_;
    return 1 if ( $t_node->get_lex_anode and $t_node->get_lex_anode->tag =~ /^...P/ );
    return 1 if ( grep { $_ eq $t_node->{t_lemma } } @group_lemmas );
    return 1 if ( $t_node->parent->functor =~ /^(CONJ|CONTRA)$/ );
    my ($mat) = grep { $_->functor eq "MAT" and not $_->{is_generated} } $t_node->get_echildren( { or_topological => 1 } );
    return (
        $mat and $mat->get_lex_anode and $mat->get_lex_anode->tag =~ /^...P/
    ) ? 1 : 0;
}

# # # finds subject among node's children and returns 1 if sb is pl
sub has_pl_sb {
    my ($t_node) = @_;
    foreach my $echild ( $t_node->get_echildren( { or_topological => 1 } ) ) {
        return 1 if ( is_subject($echild) and is_pl($echild) );
    }
    return 0;
}

# # # finds PAT among node's children and returns 1 if pat is pl
sub has_pl_pat {
    my ($t_node) = @_;
    foreach my $pat ( grep { $_->functor eq "PAT" } $t_node->get_echildren( { or_topological => 1 } ) ) {
        if ( is_pl($pat) 
            or grep { $_->functor eq "MAT" } $pat->get_echildren( { or_topological => 1 } ) ) {
            return 1;
        }
    }
    return 0;
}

# ### typ VZAJEMNE
sub rule_VZAJEMNE {
    my ($t_node) = @_;
    return ( grep { $_->t_lemma =~ /^(vzájemný|navzájem)$/ } $t_node->get_echildren( { or_topological => 1 } ) ) ? 1 : 0;
}

sub rule_WITHOUT_S {
    my ($t_node) = @_;
    return ( 
        $t_node->t_lemma =~ /^($rcp_verb_list_without_s)$/ 
        and not has_S($t_node) 
    ) ? 1 : 0;
}

sub rule_HAS_SPOLU {
    my ($t_node) = @_;
    return ( 
        $t_node->t_lemma =~ /^($rcp_verb_list_has_spolu)$/ 
        and grep { $_->t_lemma eq "společný" } $t_node->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

sub rule_MEZI_PAT {
    my ($t_node) = @_;
    if ( $t_node->t_lemma =~ /^($rcp_verb_list_mezi_pat)$/ ) {
        foreach my $echild ( $t_node->get_echildren( { or_topological => 1 } ) ) {
            if ( ($echild->functor || "") eq "PAT" 
                and ($echild->gram_sempos || "") =~ /^n/ ) {
                my @anodes = $echild->get_anodes;
                return 1 if ( grep { $_->form eq "mezi" } @anodes );
            }
        }
    }
    return 0;
}

sub rule_PL_PAT {
    my ($t_node) = @_;
    return ( $t_node->t_lemma =~ /^($rcp_verb_list_pl_pat)$/ ) ? 1 : 0;
}

sub is_rcp_cand {
    my ($t_node) = @_;
    my @rcp_lemmas = keys %rcp_lemma_cnt;
    my $lemma = $t_node->t_lemma;
    if ( ($t_node->gram_sempos || "") eq "v"
        and not $t_node->{is_generated}
        and grep { $_ eq $lemma } @rcp_lemmas
        and $lemma !~ /^(bojovat|potkat)$/
        and $rcp_lemma_cnt{$lemma}{"cnt"} > 2 ) {
        return 1;
    }
    return 0;
}

# ### typ SPOLU
sub rule_SPOLU {
    my ($t_node) = @_;
    return ( grep { $_->t_lemma eq "společný" } $t_node->get_echildren( { or_topological => 1 } ) 
        and $t_node->t_lemma =~ /\_s(e|i)$/ ) ? 1 :0;
}

# ### typ MEZI
sub rule_MEZI {
    my ($t_node) = @_;
    foreach my $echild ( $t_node->get_echildren( { or_topological => 1 } ) ) {
        return 1 if ( grep { $_->form eq "mezi" } $echild->get_anodes );
    }
    return 0;
}

# ### typ CONJ/CONTRA
sub rule_CONJ {
    my ($t_node) = @_;
    foreach my $conj ( grep { $_->functor =~ /^(CONJ|CONTRA)$/ } $t_node->children ) {
        return 1 if ( grep { is_subject($_) } $conj->children );
    }
    return 0;
}

sub process_tnode {
    my ( $self, $t_node ) = @_;
    
    my $b_has_rcp = 0;
    if ( $t_node->is_clause_head ) {
        if ( rule_VZAJEMNE($t_node)
            or rule_WITHOUT_S($t_node)
            or rule_MEZI_PAT($t_node)
            or rule_PL_PAT($t_node)
            or rule_HAS_SPOLU($t_node) ) {
            $b_has_rcp = 1;
#             print $t_node->get_address . "\n";
        }
        elsif ( is_rcp_cand($t_node) ) {
            if ( rule_SPOLU($t_node) 
                or rule_MEZI($t_node) 
                or has_SE($t_node) 
                or rule_CONJ($t_node) ) {
                $b_has_rcp = 1;
#                 print $t_node->get_address . "\n";
            }
        }
    }
    if ( $b_has_rcp ) {
        my $new_node = $t_node->create_child;
        $new_node->set_t_lemma('#Rcp');
        $new_node->set_functor($rcp_lemma_cnt{$t_node->t_lemma}{"functor"});
        $new_node->set_formeme('drop');

        #$new_node->set_attr( 'ord',     $t_node->get_attr('ord') - 0.1 );
        #$new_node->set_id($t_node->generate_new_id );
        $new_node->set_nodetype('complex');
        $new_node->set_gram_sempos('n.pron.def.pers');
        $new_node->set_is_generated(1);
        $new_node->shift_before_node($t_node);
    }
}

1;

=over

=item Treex::Block::A2T::CS::AddRcp

Adds reconstructed prodropped nodes with t-lemma #Rcp

=back

=cut

# Copyright 2011 Nguy Giang Linh

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
