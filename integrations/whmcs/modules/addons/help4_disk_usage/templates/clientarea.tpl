{if $disabled}
    <div class="alert alert-info">{$displayName|escape} client reports are currently disabled.</div>
{else}
    <h2>{$displayName|escape}</h2>
    <p class="text-muted">Latest disk and inode scan summaries for your hosting services.</p>

    {if $accounts|@count eq 0}
        <div class="alert alert-info">No disk usage scan reports are available for your services yet.</div>
    {else}
        <div class="table-responsive">
            <table class="table table-striped">
                <thead>
                    <tr>
                        <th>Service</th>
                        <th>Status</th>
                        <th>Disk</th>
                        <th>Inodes</th>
                        <th>Last Scan</th>
                        <th>Recommended Next Step</th>
                    </tr>
                </thead>
                <tbody>
                    {foreach $accounts as $account}
                        <tr>
                            <td>
                                <strong>{if $account.domain}{$account.domain|escape}{else}{$account.username|escape}{/if}</strong><br>
                                <small class="text-muted">{$account.username|escape}</small>
                            </td>
                            <td><span class="label label-default">{$account.severity|escape}</span></td>
                            <td>{$account.disk_bytes|number_format} bytes</td>
                            <td>{$account.inode_count|number_format}</td>
                            <td>{$account.scanned_at|escape}</td>
                            <td>
                                {$account.first_hint|escape}
                            </td>
                        </tr>
                    {/foreach}
                </tbody>
            </table>
        </div>
    {/if}
{/if}

<p class="text-muted text-right"><small>{$creditPrefix|escape} <a href="https://help4network.com/" target="_blank" rel="noopener">Help4 Network</a></small></p>
