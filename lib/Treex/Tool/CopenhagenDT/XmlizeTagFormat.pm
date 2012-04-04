package Treex::Tool::CopenhagenDT::XmlizeTagFormat;

use strict;
use warnings;
use Treex::Core::Log;

sub read_and_xmlize {
    my $tag_filename = shift;

#    log_info "Reading $tag_filename";

    open my $INPUT,'<:utf8',$tag_filename or log_fatal("Can't read $tag_filename");
    my $content;
    $content .= $_ while (<$INPUT>);

    return
        _add_closing_tags(
            _resolve_mismatchin_open_end_tags(
                _add_root_element(
                    _replace_unescaped_special_chars_by_entities(
                        _quote_xml_attributes_in_dag(
                            _remove_weird_xml_entities($content)
                        )
                    )
                )
            )
        );
}

sub _remove_weird_xml_entities {
    my $content = shift;
    $content =~ s/&3a;/:/g;
    $content =~ s/&7c;/|/g;
    $content =~ s/&22;/&quot;/g;
    $content =~ s/&amp;quot;/&quot;/g;
    $content =~ s/&nbsp;/ /g;
    $content =~ s/(&\w+)([^\w;])/$1;$2/g; # missing ';' in entity, e.g. ...&amp...
    $content =~ s/& amp ;/&amp;/g;
    $content =~ s/ & / &amp; /g;
    return $content;
}

sub _quote_xml_attributes_in_dag {
    my $content = shift;
    $content =~ s/\/>\n/ \/>\n/g;
    $content =~ s/ (\w+)=([^"'\s\>]+)/ $1="$2"/g;
    $content =~ s/type="-=""/type=""/g;
    return $content;
}

sub _replace_unescaped_special_chars_by_entities {
    my $content = shift;
    $content =~ s/(="[^"]*?)<([^"]*?")/$1&lt;$2/g;
    $content =~ s/([^"]="[^"]*?)>([^"]*?")/$1&gt;$2/g;
    $content =~ s/(="[^"]*?)<([^"]*?")/$1&lt;$2/g;
    $content =~ s/([^"]="[^"]*?)>([^"]*?")/$1&gt;$2/g;
    $content =~ s/"&"/"&amp;"/g;
    $content =~ s/>&</>&amp;</g;
    return $content;
}

sub _add_root_element {
    my $content = shift;
    if ( $content !~ /(<tei.2>|<root>)/ ) {
        $content =~ s/(.*)/<root>$1<\/root>/sxm;
    }
    return $content;
}

sub _resolve_mismatchin_open_end_tags {
    my $content = shift;
    $content =~ s/(<availability status="restricted">)<p>/$1/g;
    $content =~ s/<(addrline|language)>//g;
    $content =~ s/(<catRef target="[^"]*")>/$1\/>/g;
    $content =~ s/(<title>.+)<title>/$1<\/title>/g;
    return $content;
}

my %embeding = (
    W => 1,
    s => 2,
    p => 3,

    div1 => 400,
    body => 500,
    text => 700,
    'tei.2' => 900,


    align => 2,
    DTAGalign => 3,

    root => 1000,
);

sub _add_closing_tags {
    my $content = shift;

    my @segments = split /</,$content;

    my @stack;
    my @new_segments;

    my $file_changed;

    foreach my $segment (grep {/./} @segments) {

        $segment =~ /^(\/?)([^\s\/\>]+)((\s+\w+=\"[^"]*\")*)\s*(\/?)/
            or die "Error: segment not matching the expected pattern: $segment\n";

        my ($slash_before, $tag, $attribs, $slash_after) = ($1,$2,$3,$5);
#        print "$segment\n  slashbefore:$slash_before  slash_after:$slash_after  tag: $tag\n\n";

        my $stacktop = $stack[-1];

        if (not $slash_before and not $slash_after) { # new opening tag

            if (defined $embeding{$tag} and defined $stacktop and defined $embeding{$stacktop}) { # fixing unexpected opening tag

                while ( $embeding{$tag} >= $embeding{$stacktop} ) { # the same or higher-level element is opened
                    pop @stack;
#                    print "Inserting tag $stacktop\n";
                    pushlog(\@new_segments, "/$stacktop>"); # as if I have seen the closing tag
                    $stacktop = $stack[-1];
                    $file_changed = 1;
                }
            }

            push @stack, $tag;
        }

        elsif ($slash_before) {
            if ($stack[-1] eq $tag) {
                pop @stack;
            }

            elsif ( not defined $embeding{$tag} ) {
                log_warn("Embeding level of <$tag> is needed");
            }

            elsif ( not defined $embeding{$stacktop}) {
                log_warn("Embeding level of <$stacktop> is needed");
            }

            # fixing unexpected closing tag
            elsif ( $embeding{$tag} > $embeding{$stacktop} ) { # e.g. seen </root>, but missing closing </s> and </p>
                while ($embeding{$tag} > $embeding{$stacktop}) {
                    pushlog(\@new_segments, "/$stacktop>"); # as if I have seen the closing tag
                    pop @stack;
                    $stacktop = $stack[-1];
                    $file_changed = 1;
                }
            }

            else {
#                print "filename: $filename\n";
                print "expected closing tag: $stack[-1]    got: $tag\n";
            }
        }

        pushlog(\@new_segments, $segment);

    }

    if ($file_changed) {
        return  join '', map {"<$_"} @new_segments;
    }
    else {
        return $content;
    }

}

my $line;
sub pushlog {
    my ($array_ref, $value) = @_;
    push @$array_ref, $value;
    $line++;
#    print "l$line: <$value";
}



1;

__END__
