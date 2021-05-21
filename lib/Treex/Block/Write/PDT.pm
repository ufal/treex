package Treex::Block::Write::PDT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+compress' => (default=>1);

has 'version' => (isa => 'Str', is => 'ro', default => '2.0');

has 'vallex_filename' => ( isa => 'Str', is => 'rw', default => 'vallex.xml' );

sub _build_to {return '.';} # BaseTextWriter defaults to STDOUT

my ($w_fh, $m_fh, $a_fh, $t_fh);
my ($w_fn, $m_fn, $a_fn, $t_fn);

sub process_document{
    my ($self, $doc) = @_;
    $self->{extension} = '.w';
    $w_fn = $self->_get_filename($doc);
    $w_fh = $self->_open_file_handle($w_fn);
    my $print_fn = $w_fn;
    $print_fn =~ s/.w(.gz|)$/.[wamt]$1/;
    log_info "Saving to $print_fn";
    # all [wamt] files are stored in the same directory - there should be no directory in relative paths
    $w_fn = $doc->file_stem . $self->_document_extension($doc);


    $self->{extension} = '.m';
    $m_fn = $self->_get_filename($doc);
    $m_fh = $self->_open_file_handle($m_fn);
    $m_fn = $doc->file_stem . $self->_document_extension($doc);

    $self->{extension} = '.a';
    $a_fn = $self->_get_filename($doc);
    $a_fh = $self->_open_file_handle($a_fn);
    $a_fn = $doc->file_stem . $self->_document_extension($doc);

    $self->{extension} = '.t';
    $t_fn = $self->_get_filename($doc);
    $t_fh = $self->_open_file_handle($t_fn);

    my $version_flag = "";
    if ($self->version eq "3.0") {
        $version_flag = "_30";
    }
    if ($self->version eq "3.5") {
        $version_flag = "_35";
    }
    if ($self->version eq "C") {
        $version_flag = "_c";
    }

    my $doc_id = $doc->file_stem . $doc->file_number;
    my $lang   = $self->language;
    my $vallex_name = $self->vallex_filename;
    print {$w_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<wdata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head><schema href="wdata$version_flag\_schema.xml"/></head>
<meta><original_format>treex</original_format></meta>
<doc id="$doc_id">
<docmeta/>
<para>
END
    print {$m_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<mdata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head>
  <schema href="mdata$version_flag\_schema.xml" />
  <references>
    <reffile id="w" name="wdata" href="$w_fn" />
  </references>
</head>
<meta><lang>$lang</lang></meta>
END
    print {$a_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<adata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head>
  <schema href="adata$version_flag\_schema.xml" />
  <references>
   <reffile id="m" name="mdata" href="$m_fn" />
   <reffile id="w" name="wdata" href="$w_fn" />
  </references>
</head>
<trees>
END
    print {$t_fh} << "END";
<?xml version="1.0" encoding="utf-8"?>
<tdata xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
<head>
  <schema href="tdata$version_flag\_schema.xml" />
  <references>
   <reffile id="a" name="adata" href="$a_fn" />
   <reffile id="v" name="vallex" href="$vallex_name" />
  </references>
</head>
<trees>
END

    $self->Treex::Core::Block::process_document($doc);

    print {$w_fh} "</para>\n</doc>\n</wdata>";
    print {$m_fh} "</mdata>";
    print {$a_fh} "</trees>\n</adata>";
    print {$t_fh} "</trees>\n</tdata>";
    foreach my $fh ($w_fh,$m_fh,$a_fh,$t_fh) {close $fh;}
    return;
}

sub escape_xml {
    my ($self, $string) = @_;
    return if !defined $string;
    $string =~ s/&/&amp;/;
    $string =~ s/</&lt;/;
    $string =~ s/>/&gt;/;
    $string =~ s/'/&apos;/;
    $string =~ s/"/&quot;/;
    return $string;
}

sub process_atree {
    my ($self, $atree) = @_;
    my $s_id = $atree->id;
    $s_id =~ s/^a-//;
    print {$m_fh} "<s id='m-$s_id'>\n";
    foreach my $anode ($atree->get_descendants({ordered=>1})){
        my ($id, $form, $lemma, $tag) = map{$self->escape_xml($_)} $anode->get_attrs(qw(id form lemma tag), {undefs=>'?'});
        $id =~ s/^a-//;
        my $nsa = $anode->no_space_after ? '<no_space_after>1</no_space_after>' : '';
        print {$w_fh} "<w id='w-$id'><token>$form</token>$nsa</w>\n";
        print {$m_fh} "<m id='m-$id'><w.rf>w#w-$id</w.rf><form>$form</form><lemma>$lemma</lemma><tag>$tag</tag></m>\n";
    }
    print {$m_fh} "</s>\n";
    print {$a_fh} "<LM id='a-$s_id'><s.rf>m#m-$s_id</s.rf><ord>0</ord>\n<children>\n";
    foreach my $child ($atree->get_children()) { $self->print_asubtree($child); }
    print {$a_fh} "</children>\n</LM>\n";
    return;
}

sub print_asubtree {
    my ($self, $anode) = @_;
    my ($id, $afun, $ord) = $anode->get_attrs(qw(id afun ord));
    $id = 'missingID-'.rand(1000000) if !defined $id;
    $id =~ s/^a-//;
    $afun = '???' if !defined $afun;
    $ord = 0 if !defined $ord;
    print {$a_fh} "<LM id='a-$id'><m.rf>m#m-$id</m.rf><afun>$afun</afun><ord>$ord</ord>";
    print {$a_fh} '<is_member>1</is_member>' if $anode->is_member;
    print {$a_fh} '<is_parenthesis_root>1</is_parenthesis_root>' if $anode->is_parenthesis_root;
    if (my @children = $anode->get_children()){
        print {$a_fh} "\n<children>\n";
        foreach my $child (@children) { $self->print_asubtree($child); }
        print {$a_fh} "</children>\n";
    }
    print {$a_fh} "</LM>\n";
    return;
}

sub process_ttree {
    my ($self, $ttree) = @_;
    my $s_id = $ttree->id;
    $s_id =~ s/^t-//;
    my $a_s_id = $ttree->get_attr('atree.rf');
    if (!$a_s_id){
        $a_s_id = $s_id;
        $a_s_id =~ s/t_tree/a_tree/;
    }
    $a_s_id =~ s/^a-//;
    print {$t_fh} "<LM id='t-$s_id'><atree.rf>a#a-$a_s_id</atree.rf>\n<nodetype>root</nodetype>\n<deepord>0</deepord>";

    # multiword expressions in the PDT-like format:

    my $ref_mwes = $ttree->get_attr('mwes');
    my @mwes = ();
    if ($ref_mwes) {
        @mwes = @{$ref_mwes};
    }
    if (@mwes) {
        print {$t_fh} "\n<mwes>";
        foreach my $mwe (@mwes) {
	    my $id = $mwe->{'id'};
            print {$t_fh} "\n<LM id=\"$id\">";
            # simple attrs
            foreach my $attr (qw(basic-form type)) {
                my $val = $self->escape_xml($mwe->{$attr});
                print {$t_fh} "\n<$attr>$val</$attr>" if defined $val;
            }

            my $ref_target_ids = $mwe->{'tnode.rfs'};
            my @target_ids = ();
            if ($ref_target_ids) {
                @target_ids = @{$ref_target_ids};
            }
            if (@target_ids) {
                print {$t_fh} "\n<tnode.rfs>";
                foreach my $target_id (@target_ids) {
		    $target_id =~ s/^t-//;
                    print {$t_fh} "\n<LM>t-$target_id</LM>";
                }
                print {$t_fh} "\n</tnode.rfs>";
            }

            print {$t_fh} "\n</LM>";
        }
        print {$t_fh} "\n</mwes>";
    }

    print {$t_fh} "\n<children>";
    foreach my $child ($ttree->get_children()) { $self->print_tsubtree($child); }
    print {$t_fh} "</children>\n</LM>\n";
    return;
}

sub print_tsubtree {
    my ($self, $tnode) = @_;
    my ($id, $ord) = $tnode->get_attrs(qw(id ord), {undefs=>'?'});
    $id =~ s/^t-//;
    print {$t_fh} "\n<LM id='t-$id'><deepord>$ord</deepord>";

    # boolean attrs
    foreach my $attr (qw(is_dsp_root is_generated is_member is_name_of_person is_parenthesis is_state)){
        print {$t_fh} "\n<$attr>1</$attr>" if $tnode->get_attr($attr);
    }

    # simple attrs
    foreach my $attr (qw(coref_special discourse_special functor nodetype sentmod subfunctor t_lemma tfa val_frame.rf)){
        my $val = $self->escape_xml($tnode->get_attr($attr));
        $val = 'RSTR' if $attr eq 'functor' and (!$val or $val eq '???'); #TODO functor is required in PDT
        print {$t_fh} "\n<$attr>$val</$attr>" if defined $val;
    }

    # list attrs
    foreach my $attr (qw(compl.rf coref_gram.rf)){
        my @antes = $tnode->_get_node_list($attr);
        if (@antes) {
            print {$t_fh} "\n<$attr>";
            foreach my $ante (@antes) {
                my $ante_id = $ante->id;
		$ante_id =~ s/^t-//;
                print {$t_fh} "\n<LM>t-$ante_id</LM>";
            }
            print {$t_fh} "\n</$attr>";
        }
    }

    # coref_text.rf
    my @antes = $tnode->_get_node_list('coref_text.rf');
    if (@antes) {
	if ($self->version eq "3.0" or $self->version eq '3.5' or $self->version eq 'C') { # transform the old-fashioned coref_text.rf to structured coref_text (with default SPEC type)
            print {$t_fh} "\n<coref_text>";
            foreach my $ante (@antes) {
                my $ante_id = $ante->id;
		$ante_id =~ s/^t-//;
                print {$t_fh} "\n<LM><target_node.rf>t-$ante_id</target_node.rf><type>SPEC</type></LM>";
            }
            print {$t_fh} "\n</coref_text>";
	}
        else { # just keep the original old-fashioned coref_text.rf
            print {$t_fh} "\n<coref_text.rf>";
            foreach my $ante (@antes) {
                my $ante_id = $ante->id;
		$ante_id =~ s/^t-//;
                print {$t_fh} "\n<LM>t-$ante_id</LM>";
            }
            print {$t_fh} "\n</coref_text.rf>";
        }
    }

    # coref_text
    my $ref_arrows = $tnode->get_attr('coref_text');
    my @arrows = ();
    if ($ref_arrows) {
        @arrows = @{$ref_arrows};
    }
    if (@arrows) {
        print {$t_fh} "\n<coref_text>";
        foreach my $arrow (@arrows) { # take all coref_text arrows starting at the given node
	    print {$t_fh} "\n<LM>";
            # simple attrs
            # foreach my $attr (qw(target_node.rf type comment src)) {
            foreach my $attr (qw(target_node.rf type comment)) {
                my $val = $self->escape_xml($arrow->{$attr});
                if ($attr eq 'target_node.rf') {
		  $val =~ s/^t-//;
                  $val = "t-$val";
                }
                print {$t_fh} "\n<$attr>$val</$attr>" if defined $val;
            }
	    print {$t_fh} "\n</LM>";
        }
        print {$t_fh} "\n</coref_text>";
    }

    # bridging
    $ref_arrows = $tnode->get_attr('bridging');
    @arrows = ();
    if ($ref_arrows) {
        @arrows = @{$ref_arrows};
    }
    if (@arrows) {
        print {$t_fh} "\n<bridging>";
        foreach my $arrow (@arrows) { # take all bridging arrows starting at the given node
	    print {$t_fh} "\n<LM>";
            # simple attrs
            # foreach my $attr (qw(target_node.rf type comment src)) {
            foreach my $attr (qw(target_node.rf type comment)) {
                my $val = $self->escape_xml($arrow->{$attr});
                if ($attr eq 'target_node.rf') {
		  $val =~ s/^t-//;
                  $val = "t-$val";
                }
                print {$t_fh} "\n<$attr>$val</$attr>" if defined $val;
            }
	    print {$t_fh} "\n</LM>";
        }
        print {$t_fh} "\n</bridging>";
    }

    # discourse
    my $ref_discourse_arrows = $tnode->get_attr('discourse');
    my @discourse_arrows = ();
    if ($ref_discourse_arrows) {
        @discourse_arrows = @{$ref_discourse_arrows};
    }
    if (@discourse_arrows) {
        print {$t_fh} "\n<discourse>";
        foreach my $arrow (@discourse_arrows) { # take all discourse arrows starting at the given node
	    print {$t_fh} "\n<LM>";
            # simple attrs
            # foreach my $attr (qw(target_node.rf type start_group_id start_range target_group_id target_range discourse_type is_negated comment src is_altlex is_compositional connective_inserted is_implicit is_NP)) {
            foreach my $attr (qw(target_node.rf type start_group_id start_range target_group_id target_range discourse_type is_negated comment is_altlex is_compositional connective_inserted is_implicit is_NP)) {
                my $val = $self->escape_xml($arrow->{$attr});
                if ($attr eq 'target_node.rf') {
		  if ($val) {
		    $val =~ s/^t-//;
                    $val = "t-$val";
		  }
                }
                print {$t_fh} "\n<$attr>$val</$attr>" if defined $val;
            }
            # list attrs
            foreach my $attr (qw(a-connectors.rf t-connectors.rf a-connectors_ext.rf t-connectors_ext.rf)) {
                my $ref_target_ids = $arrow->{$attr};
                my @target_ids = ();
                if ($ref_target_ids) {
                    @target_ids = @{$ref_target_ids};
                }
                if (@target_ids) {
                    print {$t_fh} "\n<$attr>";
                    foreach my $target_id (@target_ids) {
                        my $prefix = "t-";
                        if ($attr =~ /^a-/) {
                          $prefix = "a-";
		          $target_id =~ s/^a-//;
                        }
			else {
			    $target_id =~ s/^t-//;
			}
                        print {$t_fh} "\n<LM>$prefix$target_id</LM>";
                    }
                    print {$t_fh} "\n</$attr>";
                }
            }
	    print {$t_fh} "\n</LM>";
        }
        print {$t_fh} "\n</discourse>";
    }

    # grammatemes
    print {$t_fh} "\n<gram>";
    foreach my $attr (qw(sempos gender number typgroup degcmp verbmod deontmod tense aspect resultative dispmod iterativeness indeftype person numertype number politeness negation diatgram factmod)){ # definiteness diathesis
        my $val = $tnode->get_attr("gram/$attr") // '';
        $val = 'n.denot' if !$val and $attr eq 'sempos'; #TODO sempos is required in PDT

        if ($self->version eq "3.0" or $self->version eq "3.5") { # grammatemes dispmod and resultative have been canceled, verbmod changed to factmod, and diatgram has been introduced (here ignoring diatgram for now)
            next if ($attr =~ /^(dispmod|resultative)$/);
            if ($attr eq 'verbmod') {
                my $factmod;
                $factmod = 'asserted' if ($val eq 'ind');
                $factmod = 'appeal' if ($val eq 'imp');
                $factmod = 'nil' if ($val =~ /^(nr|nil)$/);
                if ($val eq 'cdn') {
                    my $tense = $tnode->get_attr("gram/tense") // '';
                    $factmod = $tense eq 'ant' ? 'irreal' : 'potential';
                }
                print {$t_fh} "<factmod>$factmod</factmod>" if defined $factmod;
                next;
            }
            elsif ($attr eq 'tense') {
                my $verbmod = $tnode->get_attr("gram/verbmod") // '';
                if ($verbmod eq 'cdn') { # in PDT 3.0 and 3.5, tense is set to 'nil' in case of factmod values 'irreal' and 'potential' (i.e. originally in PDT 2.0 'cdn' in vebmod)
                    print {$t_fh} "<tense>nil</tense>";
                    next;
                }
            }
        }
        print {$t_fh} "<$attr>$val</$attr>" if $val;
    }
    print {$t_fh} "\n</gram>\n";

    # references
    my $lex = $tnode->get_lex_anode();
    my @aux = $tnode->get_aux_anodes();
    if ($lex || @aux){
        print {$t_fh} "\n<a>";
	if ($lex) {
            my $id = $lex->id;
	    $id =~ s/^a-//;
	    printf {$t_fh} "\n<lex.rf>a#a-$id</lex.rf>"
	}
        if (@aux==1){
	    my $id = $aux[0]->id;
	    $id =~ s/^a-//;
            printf {$t_fh} "\n<aux.rf>a#a-$id</aux.rf>";
        }
        if (@aux>1){
            print {$t_fh} "\n<aux.rf>";
	    for my $id (map {$_->id} @aux) {
	        $id =~ s/^a-//;
                printf {$t_fh} "\n<LM>a#a-$id</LM>";
	    }
            print {$t_fh} "\n</aux.rf>";
        }
        print {$t_fh} "\n</a>";
    }


    # recursive children
    if (my @children = $tnode->get_children()){
        print {$t_fh} "\n<children>\n";
        foreach my $child (@children) { $self->print_tsubtree($child); }
        print {$t_fh} "</children>\n";
    }
    print {$t_fh} "</LM>\n";
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::PDT - save *.w,*.m,*.a,*.t files

=head1 SYNOPSIS

 # convert *.treex files to *.w.gz,*.m.gz,*.a.gz,*.t.gz
 treex Write::PDT -- *.treex

 # convert *.treex.gz files to *.w,*.m,*.a,*.t
 treex Write::PDT compress=0 -- *.treex.gz

=head1 DESCRIPTION

Save Treex documents in PDT style PML files.

=head1 TODO

You can try reimplement this using Treex::PML if you dare.

is_member should be moved from AuxC/AuxP down (Treex vs. PDT style).

add t-layer attribute "quot"

Check links to Vallex (val_frame.rf)

Optional XML pretty printing (e.g. via xmllint --format), but anyone can do this when needed.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>
Jiri Mirovsky <mirovsky@ufal.mff.cuni.cz> (bridging, discourse, coref_text and mwe related parts)

=head1 COPYRIGHT AND LICENSE

Copyright © 2012-2020 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
