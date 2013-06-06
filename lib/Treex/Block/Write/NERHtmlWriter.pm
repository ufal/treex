package Treex::Block::Write::NERHtmlWriter;

=pod

=head1 NAME
Treex::Block::Write::NERHTMLWriter - Transforms analyzed text into html and writes it.

=head1 DESCRIPTION

Writer for Treex files with recognized named entities. Writes the text converted to html.

=cut

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

use Data::Dumper;


=pod

=over 4

=item I<process_zone>

Prints out the sentence with highlighted named entities in html format.

=cut


override 'process_document' => sub {
    my ($self, $document) = @_;
  
    # set _file_handle properly (this MUST be called if process_document is overridden)
    $self->_prepare_file_handle($document);
    
    $self->_do_before_process($document);

    # call the original process_document with _file_handle set
    $self->_do_process_document($document);

    $self->_do_after_process($document);
    
    $self->_close_file_handle();

    return;


};

sub _do_process_document {
    my ($self, $document) = @_;

    print {$self->_file_handle} "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n";
    print {$self->_file_handle} "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n";
    print {$self->_file_handle} "<head>\n";
    print {$self->_file_handle} "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />\n";
    print {$self->_file_handle} "<title>NER HTML Writer output</title>\n";
    print {$self->_file_handle} "<style type=\"text/css\" id=\"page-css\">\n";
    
    print {$self->_file_handle} "
                                body {
                                    background-color: #fffaee;
                                    font-family: Verdana, Arial, Helvetica, Sans-Serif;
                                    color: #55451c;
                                }
                                .sysnerv-named-entity.sysnerv-supertype-a {
                                    background-color: #F0D773;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-c {
                                    background-color: #B3F073;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-g {
                                    background-color: #BDD89F;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-i {
                                    background-color: #73F092;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-m {
                                    background-color: #CE84F0;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-n {
                                    background-color: #F084B4;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-o {
                                    background-color: #F87984;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-p {
                                    background-color: #73C0F0;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-q {
                                    background-color: #8073F0;
                                }
                                
                                .sysnerv-named-entity.sysnerv-supertype-t {
                                    background-color: #F5B35D;
                                }
                               
                                .sysnerv-named-entity.sysnerv-supertype-P {
                                    background-color: yellow;
                                    border: 2px solid #E41F29;
                                }
                                .sysnerv-named-entity.sysnerv-supertype-T {
                                    background-color: yellow;
                                    border: 2px solid #E41F29;
                                }
                                .sysnerv-named-entity.sysnerv-supertype-A {
                                    background-color: yellow;
                                    border: 2px solid #E41F29;
                                }
                                .sysnerv-named-entity.sysnerv-supertype-C {
                                    background-color: yellow;
                                    border: 2px solid #E41F29;
                                }

                                .sysnerv-named-entity {
                                    background-color: #775EF6;
                                }\n";


    print {$self->_file_handle} "</style>\n";
    print {$self->_file_handle} "</head>\n";
    print {$self->_file_handle} "<body>\n";
    print {$self->_file_handle} "<div class=\"content\">\n";


    $self->Treex::Core::Block::process_document($document);

    
    print {$self->_file_handle} "</div>\n";
    print {$self->_file_handle} "</body>\n";
    print {$self->_file_handle} "</html>";


}

sub process_zone {
    my ($self, $zone) = @_;

    log_fatal "ERROR: There is a zone without n_root" and die if !$zone->has_ntree;

    my $n_root = $zone->get_ntree();
    my $a_root = $zone->get_atree();
    my @anodes = $a_root->get_descendants({ordered => 1});

    my @nnodes = $n_root->get_descendants();

    my %sentence;

    for my $anode (@anodes) {
        my $aid = $anode->id;
        my $aform = $anode->get_attr("form");
        $sentence{$aid} = $aform;
    }

    for my $nnode (@nnodes) {
        my $a_refs = $nnode->get_deref_attr("a.rf");
        my @a_ents = @$a_refs;


        my $ent_beg = $a_ents[0]->id;
        my $ent_end = $a_ents[$#a_ents]->id;
        
        my $ent_type = $nnode->get_attr("ne_type");

        $sentence{$ent_beg} = "<span class=\"sysnerv-named-entity sysnerv-type-" . $ent_type . " sysnerv-supertype-" . substr($ent_type, 0, 1) . "\">" . $sentence{$ent_beg};
        $sentence{$ent_end} .= " [$ent_type]" . "</span>";
    }

    for my $anode (@anodes) {
        my $aid = $anode->id;
        print {$self->_file_handle} "$sentence{$aid}";
        print {$self->_file_handle} " " unless $anode->get_attr("no_space_after");
    }

    print "\n";

}


=pod

=back

=head1 AUTHORS

Petr Jankovsky <jankovskyp@gmail.com>

Jan Masek <honza.masek@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
