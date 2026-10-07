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
                                <br><a href="{$account.service_url|escape}">Hosting control panel</a>
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
        {foreach $accounts as $account}
            <details style="margin-bottom:16px">
                <summary><strong>{if $account.domain}{$account.domain|escape}{else}{$account.username|escape}{/if}</strong> file report</summary>
                <p class="text-muted">{$account.details.coverage|escape} &middot; {$account.scanned_at|escape}</p>
                <p><a class="btn btn-default" href="{$account.service_url|escape}">Open hosting service</a></p>
                <h3>Large files</h3>
                <div class="table-responsive"><table class="table table-striped"><thead><tr><th>Relative path</th><th>Bytes</th><th>Modified (UTC)</th></tr></thead><tbody>
                    {foreach $account.details.large_files as $file}
                        <tr><td style="overflow-wrap:anywhere">{$file.relative_path|escape}</td><td>{$file.bytes|number_format}</td><td>{$file.mtime|default:''|escape}</td></tr>
                    {foreachelse}<tr><td colspan="3">No retained large files.</td></tr>{/foreach}
                </tbody></table></div>
                <h3>Largest directory trees</h3>
                <div class="table-responsive"><table class="table table-striped"><thead><tr><th>Relative path</th><th>Bytes</th><th>Subtree entries</th></tr></thead><tbody>
                    {foreach $account.details.tree_size_hotspots as $tree}
                        <tr><td style="overflow-wrap:anywhere">{$tree.relative_path|escape}</td><td>{$tree.bytes|number_format}</td><td>{$tree.files|number_format}</td></tr>
                    {foreachelse}<tr><td colspan="3">No retained directory trees. Sync a current report for this account.</td></tr>{/foreach}
                </tbody></table></div>
                <h3>Cleanup hotspots</h3>
                <div class="table-responsive"><table class="table table-striped"><thead><tr><th>Category</th><th>Bytes</th><th>Hint</th></tr></thead><tbody>
                    {foreach $account.details.category_hotspots as $hotspot}
                        <tr><td>{$hotspot.category|escape}</td><td>{$hotspot.bytes|number_format}</td><td>{$hotspot.hint|default:''|escape}</td></tr>
                    {foreachelse}<tr><td colspan="3">No retained hotspots.</td></tr>{/foreach}
                </tbody></table></div>
            </details>
        {/foreach}
    {/if}
{/if}

<p class="text-muted text-right"><small>{$creditPrefix|escape} <a href="https://help4network.com/" target="_blank" rel="noopener">Help4 Network</a></small></p>
